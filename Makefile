include .env

fork:; forge test --fork-url $(SEPOLIA_RPC)

push:; git push origin master

mt:
	forge test --match-test $(filter-out $@,$(MAKECMDGOALS)) -vvvv

%:
	@