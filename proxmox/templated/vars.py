import os

#################################################
# Environment vars
#################################################

# proxmox node name
node = os.getenv('TEMPLATED_NODE', 'pve')

# default lvm storage name
lvm_storage = os.getenv('TEMPLATED_LVM', 'local-lvm')

# default hooks storage 
hooks_storage = os.getenv('TEMPLATED_HOOK_STORAGE', 'local-hooks')

# default log destination
log_file = os.getenv('TEMPLATED_LOG_FILE', '/var/log/templated.log')


#################################################
# Runtime vars
#################################################

# storage used to save the main hook function
hooks_storage = f'/var/lib/{node}{hooks_storage.lstrip("local")}/snippets'


#################################################
# Global vars
#################################################

# host device uuid. used by guest to know what device comes given from host
# 
# may be considered a sensitive data, and must not be changed before
# any kind of alert.
templated_disk_uuid = '3f484b83-c07a-4aad-b9b7-39c80cccab0c'