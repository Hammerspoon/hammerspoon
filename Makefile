VERSION = $(shell defaults read `pwd`/Hammerspoon/Hammerspoon-Info CFBundleVersion)
APPFILE = build/Hammerspoon.app
ZIPFILE = build/Hammerspoon-$(VERSION).zip

$(APPFILE): build $(shell find Hammerspoon -type f)
	rm -rf $@
	xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release clean build > build/release-build.log
	cp -R build/Hammerspoon/Build/Products/Release/Hammerspoon.app $@

docs: build/Hammerspoon.docset

build/Hammerspoon.docset: build/docs.sql.out build/html
	rm -rf $@
	cp -R docs/templates/Hammerspoon.docset $@
	cp build/docs.sql.out $@/Contents/Resources/docSet.dsidx
	cp build/html/* $@/Contents/Resources/Documents/

build/html: build/docs.json
	mkdir -p $@
	rm -rf $@/*
	docs/bin/genhtml $@ < $<

build/docs.sql: build/docs.json
	docs/bin/gensql < $< | sqlite3 $@

build/docs.json: build
	find . -type f \( -name '*.lua' -o -name '*.m' \) -exec cat {} + | docs/bin/gencomments | docs/bin/genjson > $@

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: release clean
