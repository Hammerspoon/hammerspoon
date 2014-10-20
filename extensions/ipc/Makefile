mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

TARGET ?= Hammerspoon

ifeq ($(TARGET), Hammerspoon)
PREFIX  ?= ~/.hammerspoon/hs
L_PATH = hs
CLI_NAME = hs
MODULE = $(current_dir)
endif

ifeq ($(TARGET), Mjolnir)
PREFIX  ?= ~/.mjolnir/mjolnir
L_PATH = mjolnir._asm
CLI_NAME = mjolnir
MODULE = _asm/$(current_dir)
endif

CLI_PREFIX ?= $(PREFIX)/$(MODULE)

OBJCFILE = internal-$(current_dir).m
LUAFILE  = init.lua
SOFILE  := $(OBJCFILE:m=so)

CC=cc
CFLAGS  += -Wall -Wextra -I ../../Pods/lua/src -fobjc-arc $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(LUAFILE) $(SOFILE) cli

$(SOFILE): $(OBJCFILE)
	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

$(OBJCFILE): internal.m
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{PATH}/$(L_PATH)/g' internal.m > $(OBJCFILE)

$(LUAFILE): template.lua
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{CLI_NAME}/$(CLI_NAME)/g' -e 's/{PATH}/$(L_PATH)/g' template.lua > init.lua

install: install-objc install-lua install-cli

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean: clean-cli
	rm -v -f $(SOFILE) $(OBJCFILE) init.lua *.rock

cli:
	PREFIX=$(CLI_PREFIX) TARGET=$(TARGET) $(MAKE) -C cli

install-cli: cli
	PREFIX=$(CLI_PREFIX) TARGET=$(TARGET) $(MAKE) -C cli install

clean-cli:
	PREFIX=$(CLI_PREFIX) TARGET=$(TARGET) $(MAKE) -C cli clean

uninstall:
	rm -v -fr $(PREFIX)/$(MODULE)
	PREFIX=$(CLI_PREFIX) TARGET=$(TARGET) $(MAKE) -C cli uninstall

.PHONY: all clean cli clean-cli uninstall
