ifndef KEYFILE
$(error set KEYFILE to your private key)
endif

VERSION = $(shell defaults read `pwd`/Mjolnir/Mjolnir-Info CFBundleVersion)
APPFILE = Mjolnir.app
TGZFILE = Mjolnir-$(VERSION).tgz
ZIPFILE = Mjolnir-$(VERSION).zip
VERSIONFILE = LATESTVERSION

release: $(TGZFILE) $(ZIPFILE) $(VERSIONFILE)
	open -R .

$(APPFILE): $(shell find Mjolnir -type f)
	rm -rf $@
	xcodebuild clean build > /dev/null
	cp -R build/Release/Mjolnir.app $@

$(TGZFILE): $(APPFILE)
	tar -czf $@ $<

$(ZIPFILE): $(APPFILE)
	zip -qr $@ $<

$(VERSIONFILE): $(TGZFILE)
	echo $(VERSION) > $@
	echo https://github.com/mjolnir-io/mjolnir/releases/download/$(VERSION)/Mjolnir-$(VERSION).tgz >> $@
	echo openssl dgst -sha1 -binary < $(TGZFILE) | openssl dgst -dss1 -sign $(KEYFILE) | openssl enc -base64 >> $@

clean:
	rm -rf $(APPFILE) $(TGZFILE) $(ZIPFILE)

.PHONY: release clean
