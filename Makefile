include .env

push:; git push origin master

mt:
	forge test --match-test $(filter-out $@,$(MAKECMDGOALS)) -vvvv

%:
	@