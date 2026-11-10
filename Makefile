RUNTIME_BUILD ?= build/runtime
RUNTIME_SRC := src/x86_64-linux
RUNTIME_START := $(RUNTIME_SRC)/rt/_start.asm
RUNTIME_SOURCES := $(filter-out $(RUNTIME_START),$(sort $(wildcard $(RUNTIME_SRC)/*/*.asm)))
RUNTIME_OBJECTS := $(patsubst $(RUNTIME_SRC)/%.asm,$(RUNTIME_BUILD)/obj/%.o,$(RUNTIME_SOURCES))
ASM_INCLUDES := $(wildcard include/asm/*.inc include/asm/*/*.inc)
RUNTIME_APPS := $(addprefix $(RUNTIME_BUILD)/apps/,cat wc)

.PHONY: phase0 phase1 phase2 phase3 phase4 phase5 phase6-files phase6-compat phase6-busybox phase6-process phase6-signal phase6-jump phase6-time phase6-calendar phase6-luafiles phase6-spawn phase6-shell phase6-path runtime apps gate FORCE phase7-exact phase7-transcendental phase7-complex phase6-lua phase6-strftime phase6-zone phase8-lifecycle phase8-openposix phase8-detectors phase8-sync phase8-c11 phase9-wctype phase9-multibyte phase9-bulk phase9-worker phase9-worker-sync phase9-wide phase9-libc-test phase9-stdio

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

phase6-lua:
	python3 tools/lua.py

phase6-process:
	python3 tools/phase6.py --process

phase6-signal:
	python3 tools/phase6.py --signal

phase6-jump:
	python3 tools/phase6.py --jump
	python3 tests/phase6/jump/checker.py

phase6-time:
	python3 tools/phase6.py --time

phase6-calendar:
	python3 tools/phase6.py --calendar

phase6-zone:
	python3 tools/phase6.py --zone

phase6-luafiles:
	python3 tools/phase6.py --luafiles

phase6-spawn:
	python3 tools/phase6.py --spawn

phase6-shell:
	python3 tools/phase6.py --shell

phase6-path:
	python3 tools/phase6.py --path

phase6-strftime:
	python3 tools/phase6.py --strftime

phase7-exact:
	python3 tools/phase7_exact.py

phase7-transcendental:
	python3 tools/phase7_transcendental.py

phase7-complex:
	python3 tools/phase7_complex.py

phase8-lifecycle:
	python3 tools/phase8.py

phase8-sync:
	python3 tools/phase8.py --sync

phase8-c11:
	python3 tools/phase8.py --c11

phase8-openposix:
	python3 tools/phase8_openposix.py

phase8-detectors:
	python3 tools/phase8_detectors.py

phase9-multibyte:
	python3 tools/phase9.py

phase9-bulk:
	python3 tools/phase9.py --suite bulk

phase9-worker:
	python3 tools/phase9.py --suite worker

phase9-worker-sync:
	python3 tools/phase9.py --suite worker-sync

phase9-wide:
	python3 tools/phase9.py --suite wide

phase9-libc-test:
	python3 tools/phase9.py --suite libc-test

phase9-stdio:
	python3 tools/phase9.py --suite stdio

phase9-wctype:
	python3 tools/phase9_wctype.py

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
