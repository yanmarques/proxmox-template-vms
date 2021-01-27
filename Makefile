install:
	@install -m 755 maybe-start-templated-vm /usr/sbin/ && \
	install start-templated-vm@.service /etc/systemd/system/
