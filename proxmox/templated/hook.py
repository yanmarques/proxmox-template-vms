from .client import Machine
from .config import ConfigIOInterface
from .host import HostDeviceFormatter, HostDeviceSeeder
from .settings import node
from .utils import (
    call,
    find_pvesh_value,
    format_size_to_int,
    parse_disk_lv,
    path_name_of,
    logger,
)

import os


def get_larger_disk(vm: Machine):
    '''
    Returns the largest disk of vm
    '''

    all_disks = vm.list_disks().items()
    if not all_disks:
        return None, None

    def sort_key(disk_pack):
        _, disk = disk_pack
        size = find_pvesh_value(disk, 'size')
        if size:
            return format_size_to_int(size)

    bus_dev, disk = sorted(all_disks, key=sort_key)[0]
    disk_lv = parse_disk_lv(disk)
    return bus_dev, disk_lv


def take_disk_snapshot(srcvm: Machine, 
                       dstvm: Machine, 
                       lv_name, 
                       disk_index, 
                       activate=True):
    '''Take snapshot from disk and return logical volume name'''

    lv_path = f'{node}/{lv_name}'
    snap = f'vm-{dstvm.vmid}-{srcvm.name}-{dstvm.name}-disk-{disk_index}-snap'

    # create snapshot
    call(f'lvcreate -n {snap} -s {lv_path}')

    # activate snapshot
    if activate:
        call(f'lvchange -a y -K {node}/{snap}')
    return snap


def disk_info(template_vm: Machine, vm: Machine=None):
    vm = vm or template_vm

    # get template root's bus/device and logical volume name
    tplt_bus_device, root_lv = get_larger_disk(template_vm)

    # default bus type: scsi
    if tplt_bus_device is None:
        tplt_bus_device = 'scsi0'

    # calculate a free device to attach
    disk_index = len(vm.list_disks(filter_by_bus=tplt_bus_device))

    # we need a way to detect the bus from template's root disk
    # and we know it is composed by a bus name and a device number
    # what we do? remove trailing digits from name
    bus = tplt_bus_device.rstrip('0123456789')

    return {
        'bus': bus,
        'index': disk_index,
        'root_lv': root_lv,
        'bus_dev': f'{bus}{disk_index}'
    }


class MemoryStats(ConfigIOInterface):
    def __init__(self, path=None, **kwargs):
        super().__init__(path or path_name_of('.memory'), **kwargs)

        # not loaded yet?
        if self._stats is None:
            self.reload()


class MachineHandler:
    def __init__(self, vmid):
        self.vm = Machine(vmid)
        self.memory = MemoryStats()
        self.seeder = HostDeviceSeeder(self.vm)
        self.formatter = HostDeviceFormatter(self.vm)

    def registered_events(self):
        return {
            'pre-start': self.on_pre_start,
            'post-stop': self.on_post_stop, 
        }

    def on_pre_start(self):
        # already seen
        if self.memory.seen(self.vm.vmid):
            return 0

        # make setup calls
        if self.vm.is_template_vm:
            setup = self._setup_template_vm
        elif self.vm.template_vmid is not None:
            setup = self._setup_template_based_vm
        else:
            logger.error('vm [%s] is not a template neither a template-based vm', 
                         self.vm.vmid)
            return 2

        # make it available
        self.formatter.format()

        # ensure setup returns OK otherwise stop
        status_code = setup() or 0
        if status_code != 0:
            # ensure device is properly removed
            self.formatter.remove_device()

            return status_code

        # create files inside host disk
        self.seeder.seed(self.formatter.device)

        # start the vm without caring about lock file
        self.vm.start('-skiplock')

        # the original call to start the vm has to fail so the later 
        # call to start be the only one which actually triggers 
        # the start procedure
        return 1

    def on_post_stop(self):
        assert self.memory.seen(self.vm.vmid), 'VM id has not registered to remove old configuration'

        # in memory we may find the last bus/device
        bus_devices = self.memory.last(self.vm.vmid)

        for bus_dev in bus_devices.split(','):
            # so detach which also removes it from boot
            result = self.vm.detach_disk(bus_dev)
            if result is True:
                logger.info('disk detached: [%s]', bus_dev)
            elif result is False:
                logger.error('failed to detach device: [%s]', bus_dev)
            else:
                logger.info('device was removed without getting unsed: [%s]', bus_dev)

        # forget about vm
        self.memory.delete(self.vm.vmid)

    def _seed_template_vm(self, target_dir):
        # create template-vm file indicating this is a template vm
        template_vm = os.path.join(target_dir, 'template-vm')
        with open(template_vm, 'w') as _: pass

    def _setup_template_vm(self):
        self.seeder.add(self._seed_template_vm)

        # obtain many disk informations
        info = disk_info(self.vm)

        # get the name of logical volume
        lv_name = self.formatter.filename

        # attach host disk
        self.vm.attach_disk(info['bus_dev'], lv_name, add_to_boot=False)

        # remember the cloned bus/device 
        self.memory.put(self.vm.vmid, info['bus_dev'])

    def _setup_template_based_vm(self):
        # create template vm and get root hard disk informations
        template_vm = Machine(self.vm.template_vmid, parse_config=False)

        # obtain many disk informations
        info = disk_info(template_vm, self.vm)

        # ensure got logical volume
        if info['root_lv'] is None:
            logger.error('unable to find logical volume of template-vm root disk')
            return 3

        # take snapshot of template root disk
        thin_pool_clone = take_disk_snapshot(template_vm,
                                            self.vm,
                                            info['root_lv'], 
                                            info['index'])
        
        # attach new disk
        self.vm.attach_disk(info['bus_dev'], thin_pool_clone)
        logger.info('attached disk: [%s]', info['bus_dev'])

        # get the name of logical volume
        lv_name = self.formatter.filename

        # next bus device in the chain
        lv_bus_dev = f'{info["bus"]}{info["index"] + 1}'

        # attach host disk
        self.vm.attach_disk(lv_bus_dev, lv_name, add_to_boot=False)
        logger.info('attached disk: [%s]', lv_bus_dev)

        # remember the cloned bus/device 
        self.memory.put(self.vm.vmid, ','.join([info['bus_dev'], lv_bus_dev]))

    
class MachineEventDispatcher:
    handler_factory = MachineHandler

    def __init__(self, *args, **kwargs):
        self._handler = self.handler_factory(*args, **kwargs)

    def dispatch(self, event):
        events = self._handler.registered_events()
        event_handler = events.get(event)

        if event_handler is None:
            logger.warn('received a not registered event [%s]', event)
            return

        logger.info('received event [%s]', event)
        
        try:
            return event_handler() or 0
        except Exception as exc:
            logger.exception(str(exc))
            return 1