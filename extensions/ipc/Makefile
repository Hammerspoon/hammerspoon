MODULE = ipc
PREFIX ?= ~/.hammerspoon/hs
CLI_PREFIX ?= $(PREFIX)/$(MODULE)

OBJCFILE = internal.m
LUAFILE  = init.lua
SOFILE  := internal-ipc.so

CC=cc
CFLAGS  += -Wall -Wextra -I ../../Pods/lua/src -fobjc-arc $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(SOFILE) cli

$(SOFILE): $(OBJCFILE)
	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

install: install-objc install-lua install-cli

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean: clean-cli
	rm -v -f $(SOFILE)

cli:
	PREFIX=$(CLI_PREFIX) $(MAKE) -C cli

install-cli: cli
	PREFIX=$(CLI_PREFIX) $(MAKE) -C cli install

clean-cli:
	PREFIX=$(CLI_PREFIX) $(MAKE) -C cli clean

uninstall-cli:
	PREFIX=$(CLI_PREFIX) $(MAKE) -C cli uninstall

uninstall: uninstall-cli
	rm -v -f $(PREFIX)/$(MODULE)/$(LUAFILE)
	rm -v -f $(PREFIX)/$(MODULE)/$(SOFILE)
	rmdir -p $(PREFIX)/$(MODULE)

.PHONY: all clean uninstall clean-cli uninstall-cli cli
