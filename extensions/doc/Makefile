MODULE = doc
PREFIX ?= ~/.hammerspoon/hs

LUAFILE  = init.lua

all:

install: install-lua

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/$(MODULE)

clean:

uninstall:
	rm -v -f $(PREFIX)/$(MODULE)/$(LUAFILE)
	rmdir -p $(PREFIX)/$(MODULE)

.PHONY: all clean uninstall
