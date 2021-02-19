#!/usr/bin/env python3

import tempfile
import traceback
import subprocess
import getpass
import logging
import json
import shlex
import shutil
import time
import re
import sys
import os

# how to identify virtual disks
scsi_re = re.compile('^scsi\\d+')
ide_re = re.compile('^ide\\d+')
virtio_re = re.compile('^virtio\\d+')
sata_re = re.compile('^sata\\d+')

# available disks to identify
available_disks = [
    scsi_re,
    ide_re,
    virtio_re,
    sata_re,
]

# global logger
logger = logging.getLogger(__file__)

# global node
node = os.getenv('TEMPLATED_NODE', 'pve')

# global disk uuid
templated_disk_uuid = '3f484b83-c07a-4aad-b9b7-39c80cccab0c'


def call(command, only_code_stat=False):
    '''Executes given command as a subprocess and returns it's output.'''

    args = shlex.split(command)
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def try_call(*args, **kwargs):
    try:
        call(*args, **kwargs)
    except subprocess.CalledProcessError as err:
        return err


def pvesh(method, 
          path, 
          options=None, 
          parse_out=None,
          call_impl=None):
    '''Wrapper to call pvesh utility.'''

    # deduce the caller function
    _caller = call_impl or call

    has_out_methods = [
        'get',
        'ls',
    ]

    # automatically set to parse output when I think it should
    if method in has_out_methods and parse_out is None:
        parse_out = True

    command = f'pvesh {method} /nodes/{node}/{path} --output-format json {options or ""}'
    result = _caller(command)
    
    if call_impl is not None:
        return result

    if parse_out:
        return json.loads(result.strip())


def path_name_of(path):
    '''Build an absolute path relative this module location.'''

    here = os.path.dirname(__file__)
    return os.path.join(here, path)


def find_pvesh_value(cfg, inner_key):
    '''
    Try to find a value inside pve configuration.
    
    Eg.:
    >>> cfg = 'key=something,order=scsi1;net0'
    >>> assert find_pvesh_value(cfg, 'order') == 'scsi1;net0'
    '''

    for _item in cfg.split(','):
        item = _item.strip()
        if item.startswith(inner_key):
            return item.split('=')[1]

    
def parse_disk_lv(disk):
    '''
    Parses proxmox hard disks syntax and return the logical volume name.

    Eg.:
    >>> disk = 'local-lvm:vm-1-disk-0,size=32G'
    >>> assert parse_disk_lv(disk) == 'vm-1-disk-0'
    '''

    opts = disk.split(',')
    if opts:
        disk_frags = opts[0].split(':')
        if len(disk_frags) > 1:
            return disk_frags[1]


def setup_logging(log_path, vmid):
    '''
    Configure logging to use file handler
    '''

    log_fmt = logging.Formatter('%(asctime)s [%(levelname)s] [VMID={}] %(message)s'.format(vmid))
    file_handler = logging.FileHandler(log_path)
    file_handler.setFormatter(log_fmt)
    logger.addHandler(file_handler)
    logger.setLevel(logging.DEBUG)


class CommonCfg:
    '''
    Handle common promox data format I/O.
    '''

    def __init__(self, path):
        self._path = path

    def write(self, data_dict):
        '''
        Write data dictionary object in a common format.
        '''

        content = (f'{k}: {v}\n' for k, v in data_dict.items())

        with open(self._path, 'w') as wr:
            return wr.write(''.join(content))

    def read(self):
        ''' 
        Parses given file using common proxmox configuration syntax.
        '''

        with open(self._path) as r:
            data = r.read()

        cfg = {}
        for _line in data.split('\n'):
            line = _line.strip()
            if line:
                key, value = line.split(':')
                cfg[key] = value.strip()
        return cfg


class ConfigIOInterface:
    def __init__(self, path, load=False):
        self._cfg_handler = CommonCfg(path)
        self._stats = None
        if load:
            self.reload()

    def last(self, key, default=None):
        return self._stats.get(key, default)

    def get(self, *args, **kwargs):
        return self.last(*args, **kwargs)

    def put(self, key, value):
        self._stats[key] = value
        self._flush()

    def update(self, **kwargs):
        self._stats.update(**kwargs)
        self._flush()

    def seen(self, key):
        return key in self._stats

    def delete(self, key):
        if self.seen(key):
            del self._stats[key]
            self._flush()

    def _flush(self):
        self._cfg_handler.write(self._stats)

    def reload(self):
        if os.path.exists(self._cfg_handler._path):
            self._stats = self._cfg_handler.read()
        else:
            self._stats = dict()


class MemoryStats(ConfigIOInterface):
    def __init__(self, path=None, **kwargs):
        super().__init__(path or path_name_of('.memory'), **kwargs)

        # not loaded yet?
        if self._stats is None:
            self.reload()


class Machine:
    '''
    This class wraps the functionality of virtual machines in proxmox.
    '''

    def __init__(self, vmid, parse_config=True):
        self.vmid = vmid
        self._cfg = ConfigIOInterface(path_name_of(f'config/{self.vmid}.conf'))
        if parse_config:
            self._cfg.reload()

    @property
    def template_vmid(self):
        '''Template's virtual machine ID'''

        return self._cfg.get('template_vmid')

    @property
    def is_template_vm(self):
        '''
        Returns whether the machine is a template
        '''

        return self._cfg.get('is_template_vm') == '1'

    @property
    def name(self):
        '''Get virtual machine name'''

        return self.fetch_config()['name']

    def get_boot_order(self):
        '''Retrieves string with boot order'''

        boot_cfg = self.fetch_config()['boot']
        return find_pvesh_value(boot_cfg, 'order')

    def list_disks(self, filter_by_bus=None, options=None):
        '''Get a dictionary of all identified disks'''

        # default disks
        _available_disks = available_disks

        if filter_by_bus:
            found_devices = filter(lambda disk_re: disk_re.match(filter_by_bus),
                                 _available_disks)
            _available_disks = list(found_devices)
            if not len(_available_disks):
                raise Exception(f'Could not filter by bus/device: {filter_by_bus}')

        disks = {}
        config = self.fetch_config(options=options)
        for key, value in config.items():
            # identify wheter config is a disk
            for disk_re in _available_disks:
                if disk_re.match(key):
                    disks[key] = value
                    break
        return disks

    def fetch_config(self, options=None):
        '''Get proxmox vm configuration'''

        return pvesh('get', f'qemu/{self.vmid}/config', options=options)

    def get_root_disk(self):
        all_disks = self.list_disks().items()
        if not all_disks:
            return None

        def sort_key(disk_pack):
            _, disk = disk_pack
            size = find_pvesh_value(disk, 'size')
            if size:
                return int(size.rstrip('G'))

        bus_dev, disk = sorted(all_disks, key=sort_key)[0]
        disk_lv = parse_disk_lv(disk)
        return bus_dev, disk_lv

    def attach_disk(self, bus_device, lv_name, options='', add_to_boot=True):
        self._hard_unlock_server()

        value = f'-{bus_device} local-lvm:{lv_name},{options}'
        pvesh('create', f'qemu/{self.vmid}/config', value)
        if add_to_boot:
            boot_order = self.get_boot_order()
            if boot_order:
                boot_order = f';{boot_order}'
            pvesh('set', f'qemu/{self.vmid}/config', f'-boot order={bus_device}{boot_order}')

    def _hard_unlock_server(self):
        # TODO find a better method to make configuration changes at runtime
        #
        # this removes old process locking file
        # it sucks and I do now know the consequences yet!
        lock_file = f'/var/run/lock/qemu-server/lock-{self.vmid}.conf'  
        if os.path.exists(lock_file) and os.path.isfile(lock_file):
            os.unlink(lock_file)

    def detach_disk(self, bus_device):
        # keep it as cache, maybe we won't use need, don't know
        disks = self.list_disks()

        if bus_device not in disks:
            return False

        disk_value = disks[bus_device]
        
        # make sure we can modify configurations
        self._hard_unlock_server()

        # detach
        pvesh('set', f'qemu/{self.vmid}/config', f'-delete {bus_device}')

        # now we have to ensure to remove the disk as well
        # it still appears as unused

        # get the logical volume so we can compare it
        disk_lv = parse_disk_lv(disk_value)

        # actually remove logical volume
        return self.remove_by_lv_name(disk_lv)

    def remove_by_lv_name(self, lv_name):
        '''
        Removes the device from logical volume name 
        '''

        config = self.fetch_config()
        for device, v in config.items():
            if lv_name in str(v):
                pvesh('set', f'qemu/{self.vmid}/config', f'-delete {device}')
                return True

    def create_disk(self, filename, size):
        options = [
            f'--filename={filename}',
            f'--vmid={self.vmid}',
            f'--size={size}',
        ]

        # create a lv disk
        err = pvesh('create',
                    'storage/local-lvm/content',
                    ' '.join(options),
                    call_impl=try_call)

        # handle error
        if err is not None:
            # device already exists
            if err.returncode == 5:
                return False

            raise err

    def start(self, options=None):
        pvesh('create', f'qemu/{self.vmid}/status/start', options=options)


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
    tplt_bus_device, root_lv = template_vm.get_root_disk()

    # calculate a free device to attach
    disk_index = len(vm.list_disks(filter_by_bus=tplt_bus_device))

    # we need a way to detect the bus from template's root disk
    # and we know it is composed by a bus name and a device number
    # what we do? remove every digit from name
    bus = ''.join(l for l in tplt_bus_device if not l.isdigit())

    return {
        'bus': bus,
        'index': disk_index,
        'root_lv': root_lv,
        'bus_dev': f'{bus}{disk_index}'
    }


class HostDeviceFormatter:
    def __init__(self, vm: Machine, disk_size: str = '4M'):
        self.vm = vm
        self.disk_size = disk_size

    @property
    def filename(self):
        return f'vm-{self.vm.vmid}-host-data'

    @property
    def device(self):
        return f'/dev/{node}/{self.filename}'

    def format(self):
        result = self.vm.create_disk(self.filename, self.disk_size)

        if result is False:
            logger.warn('logical volume [%s] already exists, removing...', 
                        self.filename)

            # disk already exists, remove it
            self.vm.remove_by_lv_name(self.filename)

            # try to recreate the disk
            assert self.vm.create_disk(self.filename, 
                                       self.disk_size) is not False, \
                        'failed to create logical volume'
            
        # create fs
        call(f'mkfs.ext4 -U {templated_disk_uuid} {self.device}')


class HostDeviceSeeder:
    def __init__(self, vm: Machine):
        self.vm = vm
        self._reset_seeders()

    def seed(self, device):
        tmp_dir = tempfile.mkdtemp()

        try:
            call(f'mount {device} {tmp_dir}')
            self._call_seeders(tmp_dir)
        finally:
            call(f'umount {tmp_dir}')

            # remove temporary directory
            shutil.rmtree(tmp_dir)
    
    def add(self, seeder):
        self._seeders.append(seeder)

    def _seed_common_guest_files(self, target_dir):
        # set hostname file as machine name
        hostname = os.path.join(target_dir, 'hostname')
        with open(hostname, 'w') as wr:
            wr.write(self.vm.name)

    def _reset_seeders(self):
        self._seeders = [self._seed_common_guest_files]

    def _call_seeders(self, target_dir):
        for seeder in self._seeders:
            seeder(target_dir)
        self._reset_seeders()


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

        setup()

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
            logger.error('received a not registered event [%s]', event)
            return

        logger.info('received event [%s]', event)
        
        try:
            return event_handler() or 0
        except Exception as exc:
            logger.exception(str(exc))
            return 1


def main():
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} vmid event')
        return 128

    vmid = sys.argv[1].strip()
    event = sys.argv[2].strip()

    setup_logging('/var/log/templated.log', vmid)

    dispatcher = MachineEventDispatcher(vmid)
    return dispatcher.dispatch(event)


if __name__ == "__main__":
	sys.exit(main())