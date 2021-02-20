from .config import ConfigIOInterface
from .vars import lvm_storage
from .utils import (
    pvesh,
    try_call,
    parse_disk_lv,
    path_name_of,
    find_pvesh_value,
    vm_config_path,
)

import os
import re

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


class Machine:
    '''
    This class wraps the functionality of virtual machines in proxmox.
    '''

    def __init__(self, 
                 vmid, 
                 parse_config=True,
                 exists=True):
        self.vmid = vmid

        # ensure it exists
        if not self.exists:
            raise ValueError(f'Unable to find VM with id {vmid}')

        # setup configuration object
        path = vm_config_path(vmid)
        self._cfg = ConfigIOInterface(path, load=parse_config)

    @property
    def template_vmid(self):
        '''Template's virtual machine ID'''

        return self._cfg.get('template_vmid')

    @template_vmid.setter
    def template_vmid(self, vmid):
        '''Set the id of the template vm it's based on'''

        self._cfg.put('template_vmid', vmid)

    @property
    def is_template_vm(self):
        '''
        Returns whether the machine is a template
        '''

        return self._cfg.get('is_template_vm') == '1'

    @is_template_vm.setter
    def is_template_vm(self, status):
        '''Set whether vm is a template'''

        value = '1' if status is True else '0'
        self._cfg.put('is_template_vm', value)


    @property
    def name(self):
        '''Get virtual machine name'''

        return self.fetch_config()['name']

    @property
    def exists(self):
        '''Checks whether the vm exists'''

        result = self.fetch_config(call_impl=try_call)

        # quite strict checking, event if errors out
        # it must match the return code
        if result is not None and result.returncode == 2:
            return False
        return True

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

    def fetch_config(self, options=None, **kwargs):
        '''Get proxmox vm configuration'''

        return pvesh('get', 
                     f'qemu/{self.vmid}/config', 
                     options=options,
                     **kwargs)

    def set_config(self, options, **kwargs):
        return pvesh('set', f'qemu/{self.vmid}/config', options, **kwargs)

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
                    f'storage/{lvm_storage}/content',
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