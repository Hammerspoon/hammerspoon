mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE = $(current_dir)

PREFIX  ?= .
OBJCFILE = internal.m MYAnonymousIdentity.m
LUAFILE  = init.lua
SOFILE  := internal.so

CC?=cc
EXTRA_CFLAGS ?= -fobjc-arc

#TODO: Put this back for 1.0
#DEBUG_CFLAGS ?= -g
DEBUG_CFLAGS = -g

CFLAGS  += $(DEBUG_CFLAGS) -Wall -Wextra -I ../../Pods/Headers/Public -F../../ -framework LuaSkin -framework Fabric $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(SOFILE)

HammerspoonCertTemplate.h:
	./mkCertTemplate.sh

$(SOFILE): HammerspoonCertTemplate.h $(OBJCFILE) $(HEADERS)
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
	rm -f HammerspoonCertTemplate.h
	rm -f cert.cer
	rm -f cert.cer.asn1

.PHONY: all clean
