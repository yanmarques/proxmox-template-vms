proxmox:
	@cd proxmox && pip install .

proxmox-uninstall:
	@pip uninstall -y templated

linux: install-lib
	@install -m 755 unix/linux/maybe-start-templated-vm /usr/sbin/
	@install -m 644 unix/linux/start-templated-vm@.service /etc/systemd/system/

linux-uninstall: clean-bin
	@systemctl disable start-templated-vm@
	@rm -f /etc/systemd/system/start-templated-vm@.service

install-lib:
	@mkdir -p /var/lib/proxmox-templated-vms/linux
	@install -m 644 unix/functions /var/lib/proxmox-templated-vms/
	@install -m 644 unix/console /var/lib/proxmox-templated-vms/
	@install -m 644 unix/linux/functions /var/lib/proxmox-templated-vms/linux/

clean-bin:
	@rm -f /usr/sbin/maybe-start-templated-vm

openbsd: install-lib
	@install -m 755 unix/openbsd/maybe-start-templated-vm /usr/sbin/
	@install -m 555 unix/openbsd/start_templated_vm /etc/rc.d/

openbsd-uninstall: clean-bin
	@rcctl disable start_templated_vm
	@rm -f /etc/rc.d/start_templated_vm

.PHONY: proxmox proxmox-uninstall linux linux-uninstall openbsd openbsd-uninstall