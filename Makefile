include .env

mt:
	forge test --match-test $(filter-out $@,$(MAKECMDGOALS)) -vvvv

%:
	@