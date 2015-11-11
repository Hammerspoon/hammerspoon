VERSION = $(shell defaults read `pwd`/Hammerspoon/Hammerspoon-Info CFBundleVersion)
APPFILE = build/Hammerspoon.app
ZIPFILE = build/Hammerspoon-$(VERSION).zip
SCHEME = Hammerspoon
CONFIGURATION = Debug

all: $(APPFILE)

release: SCHEME = Release
release: CONFIGURATION = Release
release: all

$(APPFILE): PRODUCT_DIR = $(shell xcodebuild -workspace Hammerspoon.xcworkspace -scheme $(SCHEME) -configuration $(CONFIGURATION) -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $$3 }')
$(APPFILE): build $(shell find Hammerspoon -type f)
	echo "Building Hammerspoon in $(CONFIGURATION) configuration"
	rm -rf $@
	xcodebuild -workspace Hammerspoon.xcworkspace -scheme $(SCHEME) -configuration $(CONFIGURATION) clean build > build/$(CONFIGURATION)-build.log
	cp -R ${PRODUCT_DIR}/Hammerspoon.app $@
	cp -R ${PRODUCT_DIR}/Hammerspoon.app.dSYM build/
	cp -R ${PRODUCT_DIR}/LuaSkin.framework.dSYM build/

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
	cp scripts/docs/templates/docs.css $@
	scripts/docs/bin/genhtml $@ < $<

build/html/LuaSkin:
	headerdoc2html -u -o $@ LuaSkin/LuaSkin/Skin.h
	resolveLinks $@
	mv $@/Skin_h/* $@
	rmdir $@/Skin_h

build/docs.sqlite: build/docs.json
	rm -f $@
	scripts/docs/bin/gensql < $< | sqlite3 $@

build/docs.json: build
	find . -type f \( -name '*.lua' -o -name '*.m' \) -not -path '*/sample-extensions/*' -not -path './build/*' -not -path './extensions/.build/*' -not -path './Pods/*' -exec cat {} + | scripts/docs/bin/gencomments | scripts/docs/bin/genjson > $@

build:
	mkdir -p build

clean:
	rm -rf build
	rm -rf LuaSkin.framework

clean-docs:
	rm -fr build/Hammerspoon.docset build/Hammerspoon.tgz build/html build/docs.json build/docs.sqlite

.PHONY: all release clean clean-docs
