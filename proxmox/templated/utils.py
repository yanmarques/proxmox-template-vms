from .vars import node, log_file

import subprocess
import logging
import json
import shlex
import os

logger = logging.getLogger(__file__)


def call(command, only_code_stat=False):
    '''Executes given command as a subprocess and returns it's output.'''

    args = shlex.split(command)
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def try_call(*args, **kwargs):
    '''Call command and capture any errors'''

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


def setup_logging(vmid):
    '''
    Configure logging to use file handler
    '''

    log_fmt = logging.Formatter('%(asctime)s [%(levelname)s] [VMID={}] %(message)s'.format(vmid))
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(log_fmt)
    logger.addHandler(file_handler)
    logger.setLevel(logging.DEBUG)


def format_size_to_int(size):
    # see https://stackoverflow.com/questions/12523586/python-format-size-application-converting-b-to-kb-mb-gb-tb

    power = 2**10
    power_labels = {'': 0, 'K': 1, 'M': 2, 'G': 3, 'T': 4}

    # get number removing trailing power labels
    total = int(size.rstrip(''.join(power_labels)))

    # get power from size label, removing leading numbers
    power_of = power_labels[size.lstrip('0123456789')]

    while power_of > 0:
        total *= power
        power_of -= 1
    return total