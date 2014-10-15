mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE = $(current_dir)

PREFIX  ?= .
OBJCFILE = internal.m
LUAFILE  = init.lua
SOFILE  := $(OBJCFILE:m=so)

CC=cc
CFLAGS  += -Wall -Wextra $(ARC_CFLAGS) -I ../../Pods/lua/src
LDFLAGS += -dynamiclib -undefined dynamic_lookup

all: $(SOFILE)

$(SOFILE):
	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

install: install-objc install-lua

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean:
	rm -f $(SOFILE)

.PHONY: all clean
