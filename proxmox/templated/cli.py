from .hook import MachineHandler
from .event import Dispatcher, EventNotExists
from .manager import MachineConfigManager
from .settings import var_dir
from .utils import (
    path_name_of,
    setup_hook_logging,
    setup_console_logging,
    create_directories,
    logger,
)

import os
import argparse


def to_hook(vmid, event):
    # operational initialization
    initialize()

    setup_hook_logging(vmid)

    dispatcher = Dispatcher()
    book_handler = MachineHandler(vmid, dispatcher=dispatcher)

    dispatcher.restrict_event('pre-start', 
                              book_handler.on_pre_start)

    dispatcher.restrict_event('post-stop', 
                              book_handler.on_post_stop)

    try:
        return dispatcher.dispatch(event) or 0
    except EventNotExists as event_exc:
        logger.warn(str(event_exc))
    except Exception as exc:
        logger.exception(str(exc), exc)
        return 1

    return 0


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

    create_directories(directories, mode=0o755)


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