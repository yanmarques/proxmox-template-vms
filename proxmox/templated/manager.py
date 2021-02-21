from .client import Machine
from .utils import logger
from .vars import hooks_storage    


class MachineConfigManager:
    def __init__(self, vmid):
        self.vm = Machine(vmid)

    @property
    def hook_options(self):
        return f'-hookscript {hooks_storage}:snippets/templated-hook'

    def set_template_vm(self, template_vmid):
        template = Machine(template_vmid, exists=False)
        if not template.exists:
            logger.error('template does not exists')
            return

        if template.template_vmid is not None:
            logger.warn('vm [%s] does not seems to be a template vm', 
                        template.vmid)
        
        if self.vm.template_vmid is not None:
            logger.info('already has template vmid [%s]', 
                        self.vm.template_vmid)
            choice = input('replace current template vmid? [N/y]')
            if not choice.lower() == 'y':
                return

        # save template vmid
        self.vm.template_vmid = template_vmid

        # mark as template vm
        template.is_template_vm = True
        logger.info('marked as template vm [%s]', template_vmid)

        # set hook to both vms
        self.vm.set_config(self.hook_options)
        template.set_config(self.hook_options)

    def remove_all(self):
        '''Removes any existing vm related configuration'''

        self.vm._cfg.remove('is_template_vm')
        self.vm._cfg.remove('template_vmid')
        self.vm.set_config('-delete hookscript')
