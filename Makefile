VERSION = $(shell defaults read `pwd`/Hammerspoon/Hammerspoon-Info CFBundleVersion)
APPFILE = Hammerspoon.app
ZIPFILE = Hammerspoon-$(VERSION).zip

release: $(ZIPFILE)

$(APPFILE): $(shell find Hammerspoon -type f)
	rm -rf $@
	xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon clean build > /dev/null
	cp -R build/Release/Hammerspoon.app $@

$(ZIPFILE): $(APPFILE)
	zip -qr $@ $<

clean:
	rm -rf $(APPFILE) $(ZIPFILE)

.PHONY: release clean
