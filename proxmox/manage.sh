#!/bin/sh
set -e

usage() {
    echo "Usage: $0 {install,uninstall}"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

source add-template-to-vm

case "$1" in
    install)
        install -m 755 add-template-to-vm /usr/bin
        install -m 755 templated-hook.py "$hooks_storage"
        ;;
    uninstall)
        rm -f /usr/bin/add-template-to-vm
        rm -f "${hooks_storage%/}/$hook_name"
        ;;
    *)
        usage
        ;;
esac
