mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

TARGET ?= Hammerspoon

ifeq ($(TARGET), Hammerspoon)
PREFIX  ?= ~/.hammerspoon/hs
L_PATH = hs
MODULE = $(current_dir)
endif

ifeq ($(TARGET), Mjolnir)
PREFIX  ?= ~/.mjolnir/mjolnir
L_PATH = mjolnir._asm
MODULE = _asm/$(current_dir)
endif

OBJCFILE = internal-$(current_dir).m
LUAFILE  = init.lua
SOFILE  := $(OBJCFILE:m=so)

CC=cc
CFLAGS  += -Wall -Wextra -I ../../Pods/lua/src -fobjc-arc $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(LUAFILE) $(SOFILE)

$(SOFILE): $(OBJCFILE)
	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

$(OBJCFILE): internal.m
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{PATH}/$(L_PATH)/g' internal.m > $(OBJCFILE)

$(LUAFILE): template.lua
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{PATH}/$(L_PATH)/g' template.lua > init.lua

install: install-objc install-lua

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean:
	rm -v -f $(SOFILE) $(OBJCFILE) init.lua *.rock

uninstall:
	rm -v -fr $(PREFIX)/$(MODULE)

.PHONY: all clean cli clean-cli uninstall
