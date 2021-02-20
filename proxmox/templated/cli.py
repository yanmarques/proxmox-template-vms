from templated.utils import setup_logging
from templated.hook import MachineEventDispatcher


def to_hook(vmid, event):
    setup_logging(vmid)

    dispatcher = MachineEventDispatcher(vmid)
    return dispatcher.dispatch(event)


def to_add(vmid, template_vmid):
    setup_logging(vmid)
    pass


def main():
    print('Hello World')