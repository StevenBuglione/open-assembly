RUNTIME_BUILD ?= build/runtime
RUNTIME_SRC := src/x86_64-linux
RUNTIME_START := $(RUNTIME_SRC)/rt/_start.asm
RUNTIME_SOURCES := $(filter-out $(RUNTIME_START),$(sort $(wildcard $(RUNTIME_SRC)/*/*.asm)))
RUNTIME_OBJECTS := $(patsubst $(RUNTIME_SRC)/%.asm,$(RUNTIME_BUILD)/obj/%.o,$(RUNTIME_SOURCES))
ASM_INCLUDES := $(wildcard include/asm/*.inc)

.PHONY: phase0 phase1 phase2 phase3 runtime gate FORCE

phase0:
	tools/gate --phase0

phase1:
	tools/gate --phase1

phase2:
	python3 tools/phase2.py

phase3:
	python3 tools/phase3.py

runtime: $(RUNTIME_BUILD)/crt1.o $(RUNTIME_BUILD)/libopenasm.a

$(RUNTIME_BUILD)/crt1.o: $(RUNTIME_START) $(ASM_INCLUDES) Makefile
	mkdir -p $(@D)
	tmp=$$(mktemp "$@.XXXXXX") && trap 'rm -f "$$tmp"' EXIT && \
		nasm -f elf64 -Wall -Werror -Wno-reloc-rel-dword -I include/asm/ -o "$$tmp" $< && mv -f "$$tmp" $@

$(RUNTIME_BUILD)/obj/%.o: $(RUNTIME_SRC)/%.asm $(ASM_INCLUDES) Makefile
	mkdir -p $(@D)
	tmp=$$(mktemp "$@.XXXXXX") && trap 'rm -f "$$tmp"' EXIT && \
		nasm -f elf64 -Wall -Werror -Wno-reloc-rel-dword -I include/asm/ -o "$$tmp" $< && mv -f "$$tmp" $@

$(RUNTIME_BUILD)/libopenasm.a: $(RUNTIME_OBJECTS) FORCE
	mkdir -p $(@D)
	tmp=$$(mktemp -d "$(@D)/.archive.XXXXXX") && trap 'rm -rf "$$tmp"' EXIT && \
		ar crsD "$$tmp/$(@F)" $(RUNTIME_OBJECTS) && mv -f "$$tmp/$(@F)" $@

gate:
	tools/gate "$(FUNC)"

FORCE:
