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


def call(command):
    '''Executes given command as a subprocess and returns it's output.'''

    args = shlex.split(command)
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def pvesh(method, path, options=None, parse_out=None):
    '''Wrapper to call pvesh utility.'''

    has_out_methods = [
        'get',
        'ls',
    ]

    # automatically set to parse output when I think it should
    if method in has_out_methods and parse_out is None:
        parse_out = True

    command = f'pvesh {method} /nodes/{node}/{path} --output-format json {options or ""}'
    output = call(command)
    if parse_out:
        return json.loads(output.strip())


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


def setup_logging(log_path):
    '''
    Configure logging to use file handler
    '''

    log_fmt = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
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
    def lv_data_name(self):
        '''Name of Logical Volume holding vm specific data'''

        return self._cfg.get('lv_data_name')

    @lv_data_name.setter
    def lv_data_name(self, value):
        '''Sets name of Logical Volume holding vm specific data'''

        self._cfg.put('lv_data_name', value)

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

    def atach_disk(self, bus_device, lv_name, options='', add_to_boot=True):
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
        disk_value = self.list_disks()[bus_device]
        
        # make sure we can modify configurations
        self._hard_unlock_server()

        # detach
        pvesh('set', f'qemu/{self.vmid}/config', f'-delete {bus_device}')

        # now we have to ensure to remove the disk as well
        # it still appears as unused

        # get the logical volume so we can compare it
        disk_lv = parse_disk_lv(disk_value)

        config = self.fetch_config()
        for device, v in config.items():
            if disk_lv in str(v):
                pvesh('set', f'qemu/{self.vmid}/config', f'-delete {device}')
                break

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


def ensure_machine_has_config_data(vm: Machine):
    disks = vm.list_disks()
    if 'scsi30' in disks:
        logger.debug('logical volume disk already attached to vm: %s', vm.name)
        return

    if vm.lv_data_name is None:
        name = f'vm-{vm.name}-data'

        # create a minimal lv
        call(f'lvcreate -n {name} -L 4M {node}')

        # create fs
        call(f'mkfs.ext4 /dev/{node}/{name}')

        # save created lv name
        vm.lv_data_name = name

     # attack scsi disk as cdrom media, so it goes read-only to guest vm
        vm.atach_disk('scsi30', 
                      vm.lv_data_name, 
                      options='media=cdrom', 
                      add_to_boot=False)


def configure_vm_and_jump(vm, memory):
    # create template vm and get root hard disk informations
    template_vm = Machine(vm.template_vmid, parse_config=False)

    # get template root's bus/device and logical volume name
    tplt_bus_device, root_lv = template_vm.get_root_disk()

    # calculate a free device to attach
    vm_disk_dev = len(vm.list_disks(filter_by_bus=tplt_bus_device))

    # take snapshot of template root disk
    thin_pool_clone = take_disk_snapshot(template_vm,
                                         vm,
                                         root_lv, 
                                         vm_disk_dev)

    # we need a way to detect the bus from template's root disk
    # and we know it is composed by a bus name and a device number
    # what we do? remove every digit from name
    bus = ''.join(l for l in tplt_bus_device if not l.isdigit())
    cloned_bus_dev = f'{bus}{vm_disk_dev}' 

    # remember the cloned bus/device 
    memory.put(vm.vmid, cloned_bus_dev)

    # attach new disk
    vm.atach_disk(cloned_bus_dev, thin_pool_clone)

    # start the vm without caring about lock file
    vm.start('-skiplock')

    # the original call to start the vm has to fail so the later 
    # call to start be the only one which actually triggers 
    # the start procedure
    return 1


def on_pre_start(vm: Machine, memory: MemoryStats):
    # already seen
    if memory.seen(vm.vmid):
        return 0

    ensure_machine_has_config_data(vm)

    return configure_vm_and_jump(vm, memory)


def remove_old_configuration(vm: Machine, memory: MemoryStats):
    assert memory.seen(vm.vmid), 'VM id has not registered to remove old configuration'

    # in memory we may find the last bus/device
    bus_device = memory.last(vm.vmid)

    # so detach which also removes it from boot
    vm.detach_disk(bus_device)

    # forget about vm
    memory.delete(vm.vmid)


def main():
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} vmid phase')
        return 128

    vmid = sys.argv[1].strip()
    phase = sys.argv[2].strip()

    available_phases = {
        'pre-start': on_pre_start,
        'post-stop': remove_old_configuration, 
    }

    setup_logging('/var/log/templated.log')

    logger.info('received hook from user: %s', getpass.getuser())

    handler = available_phases.get(phase)
    if handler is None:
        logger.error('unknow phase [%s] with vmid [%s]', phase, vmid)
    else:
        logger.info('received vmid [%s] with phase [%s]', vmid, phase)
        vm = Machine(vmid)
        memory = MemoryStats()

        try:
            return handler(vm, memory) or 0
        except Exception as exc:
            logger.exception(str(exc))

    return 0


if __name__ == "__main__":
	sys.exit(main())