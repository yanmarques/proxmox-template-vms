proxmox-install:
	@cd proxmox && bash manage.sh install

proxmox-uninstall:
	@cd proxmox && bash manage.sh uninstall

linux: install-lib
	@install -m 755 unix/linux/maybe-start-templated-vm /usr/sbin/
	@install -m 644 unix/linux/start-templated-vm@.service /etc/systemd/system/

linux-uninstall: clean-bin
	@systemctl disable start-templated-vm@
	@rm -f /etc/systemd/system/start-templated-vm@.service

install-lib:
	@mkdir -p /var/lib/proxmox-templated-vms/linux
	@install -m 644 unix/functions /var/lib/proxmox-templated-vms/
	@install -m 644 unix/linux/functions /var/lib/proxmox-templated-vms/linux/

clean-bin:
	@rm -f /usr/sbin/maybe-start-templated-vm

openbsd-install: install-bin
	@install -m 555 unix/services/rc/start_templated_vm /etc/rc.d/

openbsd-uninstall: clean-bin
	@rcctl disable start_templated_vm
	@rm -f /etc/rc.d/start_templated_vm

.PHONY: proxmox-install proxmox-uninstall linux linux-uninstall openbsd-install openbsd-uninstall