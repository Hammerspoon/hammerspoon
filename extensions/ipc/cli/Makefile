PREFIX ?= /usr/local
LDFLAGS += -framework CoreFoundation -ledit
TARGET ?= Hammerspoon

ifeq ($(TARGET), Hammerspoon)
BUNDLE = org.hammerspoon.Hammerspoon
L_PATH = hs
CLI_NAME = hs
endif

ifeq ($(TARGET), Mjolnir)
BUNDLE = org.degutis.Mjolnir
L_PATH = mjolnir._asm
CLI_NAME = mjolnir
endif

all: $(CLI_NAME) $(CLI_NAME).1

$(CLI_NAME): $(CLI_NAME).o

$(CLI_NAME).o: $(CLI_NAME).c

$(CLI_NAME).c: template.c
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{BUNDLE}/$(BUNDLE)/g' template.c > $(CLI_NAME).c

$(CLI_NAME).1: template.man
	sed -e 's/{TARGET}/$(TARGET)/g' -e 's/{CLI_NAME}/$(CLI_NAME)/g' -e 's/{PATH}/$(L_PATH)/g' template.man > $(CLI_NAME).1

install: $(CLI_NAME) $(CLI_NAME).1
	mkdir -p $(PREFIX)/{share/man/man1,bin}
	install -m 0755 $(CLI_NAME) $(PREFIX)/bin
	install -m 0644 $(CLI_NAME).1 $(PREFIX)/share/man/man1

uninstall:
	rm -v -fr $(PREFIX)/bin/$(CLI_NAME)
	rm -v -fr $(PREFIX)/share/man/man1/$(CLI_NAME).1

clean:
	rm -v -rf $(CLI_NAME).o $(CLI_NAME) $(CLI_NAME).1 $(CLI_NAME).c

.PHONY: all install uninstall clean
