.PHONY: test check
check:
	bash -n bin/session-ledger lib/lock.sh tests/test.sh
test: check
	bash tests/test.sh
