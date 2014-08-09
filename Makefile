ifndef KEYFILE
$(error set KEYFILE to your private key)
endif

VERSION = $(shell defaults read `pwd`/Mjolnir/Mjolnir-Info CFBundleVersion)
APPFILE = Mjolnir.app
TGZFILE = Mjolnir-$(VERSION).tgz
ZIPFILE = Mjolnir-$(VERSION).zip

all: $(TGZFILE) $(ZIPFILE) sign

$(APPFILE): $(shell find Mjolnir -type f)
	rm -rf $@
	xcodebuild clean build > /dev/null
	cp -R build/Release/Mjolnir.app $@

$(TGZFILE): $(APPFILE)
	tar -czf $@ $<

$(ZIPFILE): $(APPFILE)
	zip -qr $@ $<

sign: $(TGZFILE)
	@openssl dgst -sha1 -binary < $(TGZFILE) | openssl dgst -dss1 -sign $(KEYFILE) | openssl enc -base64

clean:
	rm -rf $(APPFILE) $(TGZFILE) $(ZIPFILE)

.PHONY: all sign clean
