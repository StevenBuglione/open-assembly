RUNTIME_BUILD ?= build/runtime
RUNTIME_SRC := src/x86_64-linux
RUNTIME_START := $(RUNTIME_SRC)/rt/_start.asm
RUNTIME_SOURCES := $(filter-out $(RUNTIME_START),$(sort $(wildcard $(RUNTIME_SRC)/*/*.asm)))
RUNTIME_OBJECTS := $(patsubst $(RUNTIME_SRC)/%.asm,$(RUNTIME_BUILD)/obj/%.o,$(RUNTIME_SOURCES))
ASM_INCLUDES := $(wildcard include/asm/*.inc include/asm/*/*.inc)
RUNTIME_APPS := $(addprefix $(RUNTIME_BUILD)/apps/,cat wc)

.PHONY: phase0 phase1 phase2 phase3 phase4 phase5 phase6-files phase6-compat phase6-busybox runtime apps gate FORCE

phase0:
	tools/gate --phase0

phase1:
	tools/gate --phase1

phase2:
	python3 tools/phase2.py

phase3:
	python3 tools/phase3.py

phase4:
	python3 tools/phase4.py

phase5:
	python3 tools/phase5.py

phase6-files:
	python3 tools/phase6.py

phase6-compat:
	python3 tools/phase6.py --compat

phase6-busybox:
	python3 tools/busybox.py

runtime: $(RUNTIME_BUILD)/crt1.o $(RUNTIME_BUILD)/libopenasm.a

apps: $(RUNTIME_APPS)

$(RUNTIME_BUILD)/app-obj/%.o: apps/%/main.asm $(ASM_INCLUDES) Makefile
	mkdir -p $(@D)
	tmp=$$(mktemp "$@.XXXXXX") && trap 'rm -f "$$tmp"' EXIT && \
		nasm -f elf64 -Wall -Werror -Wno-reloc-rel-dword -I include/asm/ -o "$$tmp" $< && \
		tools/elf-audit --assembly-object "$$tmp" && mv -f "$$tmp" $@

$(RUNTIME_BUILD)/apps/%: $(RUNTIME_BUILD)/app-obj/%.o $(RUNTIME_BUILD)/crt1.o $(RUNTIME_BUILD)/libopenasm.a
	mkdir -p $(@D)
	tmp=$$(mktemp -d "$(@D)/.app.XXXXXX") && trap 'rm -rf "$$tmp"' EXIT && \
		ld -m elf_x86_64 -static -no-pie -z noexecstack --fatal-warnings --no-undefined --gc-sections \
			-e _start -o "$$tmp/$(@F)" $(RUNTIME_BUILD)/crt1.o $< $(RUNTIME_BUILD)/libopenasm.a && \
		tools/elf-audit "$$tmp/$(@F)" && mv -f "$$tmp/$(@F)" $@

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
