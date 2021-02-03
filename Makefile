proxmox-install:
	@cd proxmox && bash manage.sh install

proxmox-uninstall:
	@cd proxmox && bash manage.sh uninstall

linux-install: install-bin
	@install -m 644 unix/services/systemd/start-templated-vm@.service /etc/systemd/system/

linux-uninstall: clean-bin
	@systemctl disable start-templated-vm@
	@rm -f /etc/systemd/system/start-templated-vm@.service

install-bin:
	@install -m 755 unix/maybe-start-templated-vm /usr/sbin/

clean-bin:
	@rm -f /usr/sbin/maybe-start-templated-vm

openbsd-install: install-bin
	@install -m 555 unix/services/rc/start_templated_vm /etc/rc.d/

openbsd-uninstall: clean-bin
	@rcctl disable start_templated_vm
	@rm -f /etc/rc.d/start_templated_vm

.PHONY: proxmox-install proxmox-uninstall linux-install linux-uninstall openbsd-install openbsd-uninstall