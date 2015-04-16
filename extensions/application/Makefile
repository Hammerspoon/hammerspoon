mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE = $(current_dir)

PREFIX  ?= .
OBJCFILE = internal.m watcher.m
LUAFILE  = init.lua
SOFILE  := $(OBJCFILE:m=so)
#TODO: Put this back after 1.0 DEBUG_CFLAGS ?= -g
DEBUG_CFLAGS = -g

CC=cc
CFLAGS  += $(DEBUG_CFLAGS) -Wall -Wextra -I ../../Pods/lua/src -fobjc-arc -F../../ -framework Fabric $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(SOFILE)

$(SOFILE): $(OBJCFILE) $(HEADERS)
	$(CC) $(@:so=m) $(CFLAGS) $(LDFLAGS) -o $@

install: install-objc install-lua

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean:
	rm -v -f $(SOFILE)

.PHONY: all clean
