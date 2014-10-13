VERSION = $(shell defaults read `pwd`/Mjolnir/Mjolnir-Info CFBundleVersion)
APPFILE = Mjolnir.app
TGZFILE = Mjolnir-$(VERSION).tgz
ZIPFILE = Mjolnir-$(VERSION).zip
VERSIONFILE = LATESTVERSION

release: $(TGZFILE) $(ZIPFILE) $(VERSIONFILE)

$(APPFILE): $(shell find Mjolnir -type f)
	rm -rf $@
	xcodebuild -workspace Mjolnir.xcworkspace -scheme Mjolnir clean build > /dev/null
	cp -R build/Release/Mjolnir.app $@

$(TGZFILE): $(APPFILE)
	tar -czf $@ $<

$(ZIPFILE): $(APPFILE)
	zip -qr $@ $<

$(VERSIONFILE): $(TGZFILE)
	test -n "$(KEYFILE)"
	echo $(VERSION) > $@
	echo https://github.com/sdegutis/mjolnir/releases/download/$(VERSION)/Mjolnir-$(VERSION).tgz >> $@
	openssl dgst -sha1 -binary < $(TGZFILE) | openssl dgst -dss1 -sign $(KEYFILE) | openssl enc -base64 >> $@

clean:
	rm -rf $(APPFILE) $(TGZFILE) $(ZIPFILE)

.PHONY: release clean
