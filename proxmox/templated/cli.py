from .hook import MachineEventDispatcher
from .manager import MachineConfigManager
from .vars import var_dir
from .utils import (
    path_name_of,
    setup_hook_logging,
    setup_console_logging,
    logger,
)

import os
import argparse


def to_hook(vmid, event):
    # operational initialization
    initialize()

    setup_hook_logging(vmid)

    dispatcher = MachineEventDispatcher(vmid)
    return dispatcher.dispatch(event)


def process_request(arguments):
    manager = MachineConfigManager(arguments.vmid)

    action = arguments.action
    if action == 'add':
        manager.set_template_vm(arguments.template_vmid)
    elif action == 'remove':
        manager.remove_all()

    logger.info('done!')


def initialize():
    directories = [
        var_dir,
        path_name_of('config')
    ]

    # ensure directories exists
    for directory in directories:
        os.makedirs(directory, mode=0o755, exist_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', 
                                     help='What to do with vm',
                                     choices=['add', 'remove'])
    parser.add_argument('vmid',
                            help='Target vm id')
    parser.add_argument('template_vmid',
                            nargs='?',
                            help='ID of template vm to add. Only needed when action is "add"')

    args = parser.parse_args()
    if args.action == 'add' and args.template_vmid is None:
        parser.error('action is add, the following arguments are required: template_vm_id')
        parser.print_usage()
        parser.exit(1)

    initialize()
    setup_console_logging()
    process_request(args)