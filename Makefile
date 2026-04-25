.PHONY: test test-unit lint submodules

test: test-unit

test-unit:
	bats tests/unit/

lint:
	shellcheck backup.sh lib/*.sh

# Run once after cloning to fetch bats-assert, bats-file, bats-support
submodules:
	git submodule update --init --recursive
