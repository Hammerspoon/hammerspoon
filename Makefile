VERSION = $(shell defaults read `pwd`/Hammerspoon/Hammerspoon-Info CFBundleVersion)
APPFILE = build/Hammerspoon.app
ZIPFILE = build/Hammerspoon-$(VERSION).zip
PRODUCT_DIR = $(shell xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $$3 }')

$(APPFILE): build $(shell find Hammerspoon -type f)
	rm -rf $@
	xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release clean build > build/release-build.log
	mv ${PRODUCT_DIR}/Hammerspoon.app $@

docs: build/Hammerspoon.docset

build/Hammerspoon.docset: build/docs.sqlite build/html
	rm -rf $@
	cp -R scripts/docs/templates/Hammerspoon.docset $@
	mv build/docs.sqlite $@/Contents/Resources/docSet.dsidx
	cp build/html/* $@/Contents/Resources/Documents/
	tar -czf build/Hammerspoon.tgz -C build Hammerspoon.docset

build/html: build/docs.json
	mkdir -p $@
	rm -rf $@/*
	scripts/docs/bin/genhtml $@ < $<

build/docs.sqlite: build/docs.json
	scripts/docs/bin/gensql < $< | sqlite3 $@

build/docs.json: build
	find . -type f \( -name '*.lua' -o -name '*.m' \) -not -path '*/sample-extensions/*' -not -path './build/*' -not -path './extensions/.build/*' -exec cat {} + | scripts/docs/bin/gencomments | scripts/docs/bin/genjson > $@

build:
	mkdir -p build

clean:
	rm -rf build
	rm -rf extensions/.build
	rm -rf extensions/*/*.dSYM

.PHONY: release clean
