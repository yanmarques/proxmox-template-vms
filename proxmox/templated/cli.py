from templated.utils import setup_logging
from templated.hook import MachineEventDispatcher
from templated.vars import var_dir

import os


def to_hook(vmid, event):
    initialize(vmid)

    dispatcher = MachineEventDispatcher(vmid)
    return dispatcher.dispatch(event)


def to_add(vmid, template_vmid):
    pass


def initialize(vmid):
    setup_logging(vmid)

    # ensure var directory exists
    os.makedirs(var_dir, mode=0o755, exist_ok=True)


def main():
    print('Hello World')