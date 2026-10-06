.PHONY: build install uninstall demo-eye demo-walk spec clean

## Compile and assemble MacBreak.app into build/
build:
	@./scripts/build.sh

## Build, install to /Applications, register the login agent and start it
install:
	@./scripts/install.sh

## Stop it and remove the agent and the app bundle
uninstall:
	@./scripts/uninstall.sh

## Show a look-away overlay after 6s, lasting 5s
demo-eye: build
	@MACBREAK_BREAK_SECONDS=6 MACBREAK_DURATION_SECONDS=5 ./build/MacBreak

## Show a walk overlay after 6s, lasting 5s
demo-walk: build
	@MACBREAK_WALK_SECONDS=6 MACBREAK_DURATION_SECONDS=5 ./build/MacBreak

## Validate the OpenSpec specifications
spec:
	@openspec validate --all

clean:
	@rm -rf build
	@echo "Removed build/"
