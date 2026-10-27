DEVICE ?= fenix8solar47mm
CIQ_SDK ?=
DEVELOPER_KEY ?= $(HOME)/.ssh/developer_key
.DEFAULT_GOAL := build

.PHONY: build build-both test check-tools

check-tools:
	@test -x "$(CIQ_SDK)/bin/monkeyc" || { echo "Set CIQ_SDK to your Connect IQ SDK directory."; exit 1; }
	@test -f "$(DEVELOPER_KEY)" || { echo "Set DEVELOPER_KEY to your private DER signing key."; exit 1; }

build: check-tools
	@mkdir -p bin
	"$(CIQ_SDK)/bin/monkeyc" -f monkey.jungle -d "$(DEVICE)" -y "$(DEVELOPER_KEY)" -o "bin/SourdoughTimer-$(DEVICE).prg" -l 3 -w

build-both: check-tools
	$(MAKE) build DEVICE=fenix8solar47mm
	$(MAKE) build DEVICE=fenix8solar51mm

test: check-tools
	@mkdir -p bin
	"$(CIQ_SDK)/bin/monkeyc" -f monkey.jungle -d "$(DEVICE)" -y "$(DEVELOPER_KEY)" -o "bin/SourdoughTimer-tests.prg" -l 3 -w -t
	"$(CIQ_SDK)/bin/monkeydo" bin/SourdoughTimer-tests.prg "$(DEVICE)" -t
