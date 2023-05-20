
.PHONY: test

test:
	@echo "Running test..."
	@forge test --block-number 17297904 --fork-url $(FORK_URL) -vvv
