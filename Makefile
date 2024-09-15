include .env

fork:; forge test --fork-url $(SEPOLIA_RPC)

push:; git push origin master

mt:
	forge test --match-test $(filter-out $@,$(MAKECMDGOALS)) -vvvv

report:
	forge coverage --report debug >debug.txt
	python3 debug_refiner.py

summary:; forge coverage --report summary >summary.txt

%:
	@