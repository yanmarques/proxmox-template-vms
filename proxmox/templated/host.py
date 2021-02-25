from .client import Machine
from .settings import node, templated_disk_uuid
from .utils import call, logger

import tempfile
import shutil
import os


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

            self.remove_device()

            # try to recreate the disk
            assert self.vm.create_disk(self.filename, 
                                       self.disk_size) is not False, \
                        'failed to create logical volume'
            
        # create fs
        call(f'mkfs.ext4 -U {templated_disk_uuid} {self.device}')

    def remove_device(self):
        # TODO use a reliable method to remove lv
        # disk already exists, remove it
        call(f'lvremove -y {self.device}')


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