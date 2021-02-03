proxmox-install:
	@cd proxmox && bash manage.sh install

proxmox-uninstall:
	@cd proxmox && bash manage.sh uninstall

linux-install:
	@install -m 755 linux/maybe-start-templated-vm /usr/sbin/ && \
	install -m 644 linux/start-templated-vm@.service /etc/systemd/system/

linux-uninstall:
	@rm -f /usr/sbin/maybe-start-templated-vm && \
	rm -f /etc/systemd/system/start-templated-vm@.service

openbsd-install:
	@install -m 755 linux/maybe-start-templated-vm /usr/sbin/

.PHONY: proxmox proxmox-uninstall linux-install linux-uninstall