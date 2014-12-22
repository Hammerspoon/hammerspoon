MODULE = settings
PREFIX ?= ~/.hammerspoon/hs

OBJCFILE = internal.m
LUAFILE  = init.lua
SOFILE  := internal-settings.so
DEBUG_CFLAGS ?= -g

CC=cc
CFLAGS  += $(DEBUG_CFLAGS) -Wall -Wextra -I ../../Pods/lua/src -I /usr/local/include/lua5.2 -fobjc-arc $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(SOFILE)

$(SOFILE): $(OBJCFILE)
	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

install: install-objc install-lua

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean:
	rm -v -f $(SOFILE)

uninstall:
	rm -v -f $(PREFIX)/$(MODULE)/$(LUAFILE)
	rm -v -f $(PREFIX)/$(MODULE)/$(SOFILE)
	rmdir -p $(PREFIX)/$(MODULE) ; exit 0

.PHONY: all clean uninstall
