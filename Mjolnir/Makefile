LUAFILES  = setup.lua
OBJCFILES = core.m
DOCSET    = Mjolnir.docset
DASHSQL   = $(DOCSET)/Contents/Resources/docSet.dsidx
DASHHTML  = $(DOCSET)/Contents/Resources/Documents

all: $(DOCSET)

docs.json: $(OBJCFILES) $(LUAFILES)
	ruby gendocs.rb --json $^ > $@

$(DASHSQL): docs.json
	rm $@
	echo 'CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);' | sqlite3 $@
	echo 'CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);' | sqlite3 $@
	ruby gendocs.rb --sqlin $^ | sqlite3 $@

$(DASHHTML): docs.json
	rm -f $@/core.html
	ruby gendocs.rb --html $^ $@

$(DOCSET): $(DASHHTML) $(DASHSQL)

clean:
	rm -rf docs.json

.PHONY: all clean
