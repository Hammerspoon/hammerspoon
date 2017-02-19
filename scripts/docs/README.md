### To write docs

1. Any comment that starts with `---` or `///` is a doc-string (i.e. 3 comment-characters in a row)
2. Doc-strings continue on until a non-docstring line
3. Doc-strings for modules contain `=== my.modulename ===`, then any number of lines describing it
4. Doc-strings for items (functions, variables, etc.) go like this:
   1. The first line starts with `my.modulename.item` or `my.modulename:item` -- this is the item name
   2. Any non-alphanumeric character ends the item name and is ignored, i.e. parentheses or spaces:
      1. `my.modulename:foo()`
      2. `my.modulename:foo(bar) -> string`
      3. `my.modulename.foo(bar, fn(int) -> int)`
      4. `my.modulename.foo = {}`
   3. The second line is a single captitalized word, like "Variable" or "Function" or "Method" or "Constant" or "Field"
   4. The remaining lines describe the item
5. Any comment that starts with 4 comment-characters is ignored
7. Only files ending in `.lua` or `.m` are scanned

### To generate docs

~~~bash
$ pip install --user -r requirements.txt
$ make docs
~~~

Your output will now be in build/ in the following forms:
 * Hammerspoon.docset - Docs bundle for the excellent "Dash" browser
 * html - HTML docs
