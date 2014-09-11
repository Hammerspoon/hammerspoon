all: build/Mjolnir.tgz

build/Mjolnir.tgz: build/Mjolnir.docset
	tar --exclude='.DS_Store' -cvzf $@ -C build Mjolnir.docset

build/Mjolnir.docset: build/docs.sql.out build/docs.html.d
	rm -rf $@
	cp -R templates/Mjolnir.docset $@
	cp build/docs.sql.out $@/Contents/Resources/docSet.dsidx
	cp build/docs.html.d/* $@/Contents/Resources/Documents/

build/docs.html.d: build/docs.json
	mkdir -p $@
	rm -f $@/*
	bin/genhtml $@ < $<

build/docs.sql.out: build/docs.sql
	sqlite3 $@ < $<

build/docs.sql: build/docs.json
	bin/gensql < $< > $@

build/docs.json: build/comments.json
	bin/genjson < $< > $@

build/comments.json: build/candidates.txt
	bin/gencomments < $< > $@

build/candidates.txt: build/candidates
	find $< -type f \( -name '*.lua' -o -name '*.m' \) -not -path '*/_docsignore/*' -exec cat {} + > $@

build/candidates: build/repos.txt
	mkdir -p $@
	bin/download $@ < $<

build/repos.txt: build/wiki
	cp build/wiki/Repos.md $@

build/wiki:
	git clone https://github.com/sdegutis/mjolnir.wiki.git $@

clean:
	rm -rf build/*

.PHONY: all clean
