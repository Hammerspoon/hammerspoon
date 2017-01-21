# SLAXML
SLAXML is a pure-Lua SAX-like streaming XML parser. It is more robust than
many (simpler) pattern-based parsers that exist ([such as mine][1]), properly
supporting code like `<expr test="5 > 7" />`, CDATA nodes, comments, namespaces,
and processing instructions.

It is currently not a truly valid XML parser, however, as it allows certain XML that
is syntactically-invalid (not well-formed) to be parsed without reporting an error.

[1]: http://phrogz.net/lua/AKLOMParser.lua

## Features

* Pure Lua in a single file (two files if you use the DOM parser).
* Streaming parser does a single pass through the input and reports what it sees along the way.
* Supports processing instructions (`<?foo bar?>`).
* Supports comments (`<!-- hello world -->`).
* Supports CDATA sections (`<![CDATA[ whoa <xml> & other content as text ]]>`).
* Supports namespaces, resolving prefixes to the proper namespace URI (`<foo xmlns="bar">` and `<wrap xmlns:bar="bar"><bar:kittens/></wrap>`).
* Supports unescaped greater-than symbols in attribute content (a common failing for simpler pattern-based parsers).
* Unescapes named XML entities (`&lt; &gt; &amp; &quot; &apos;`) and numeric entities (e.g. `&#10;`) in attributes and text nodes (but—properly—not in comments or CDATA). Properly handles edge cases like `&#38;amp;`.
* Optionally ignore whitespace-only text nodes (as appear when indenting XML markup).
* Includes a DOM parser that is both a convenient way to pull in XML to use as well as a nice example of using the streaming parser.
* Does not add any keys to the global namespace.

## Usage

```lua
local SLAXML = require 'slaxml'

local myxml = io.open('my.xml'):read('*all')

-- Specify as many/few of these as you like
parser = SLAXML:parser{
  startElement = function(name,nsURI,nsPrefix)       end, -- When "<foo" or <x:foo is seen
  attribute    = function(name,value,nsURI,nsPrefix) end, -- attribute found on current element
  closeElement = function(name,nsURI)                end, -- When "</foo>" or </x:foo> or "/>" is seen
  text         = function(text)                      end, -- text and CDATA nodes
  comment      = function(content)                   end, -- comments
  pi           = function(target,content)            end, -- processing instructions e.g. "<?yes mon?>"
}

-- Ignore whitespace-only text nodes and strip leading/trailing whitespace from text
-- (does not strip leading/trailing whitespace from CDATA)
parser:parse(myxml,{stripWhitespace=true})
```

If you just want to see if it will parse your document correctly, you can simply do:

```lua
local SLAXML = require 'slaxml'
SLAXML:parse(myxml)
```

…which will cause SLAXML to use its built-in callbacks that print the results as they are seen.

## DOM Builder

If you simply want to build tables from your XML, you can alternatively:

```lua
local SLAXML = require 'slaxdom' -- also requires slaxml.lua; be sure to copy both files
local doc = SLAXML:dom(myxml)
```

The returned table is a 'document' composed of tables for elements, attributes, text nodes, comments, and processing instructions. See the following documentation for what each supports.

### DOM Table Features

* **Document** - the root table returned from the `SLAXML:dom()` method.
  * <strong>`doc.type`</strong> : the string `"document"`
  * <strong>`doc.name`</strong> : the string `"#doc"`
  * <strong>`doc.kids`</strong> : an array table of child processing instructions, the root element, and comment nodes.
  * <strong>`doc.root`</strong> : the root element for the document
* **Element**
  * <strong>`someEl.type`</strong> : the string `"element"`
  * <strong>`someEl.name`</strong> : the string name of the element (without any namespace prefix)
  * <strong>`someEl.nsURI`</strong> : the namespace URI for this element; `nil` if no namespace is applied
  * <strong>`someEl.attr`</strong> : a table of attributes, indexed by name and index
      * `local value = someEl.attr['attribute-name']` : any namespace prefix of the attribute is not part of the name
      * `local someAttr = someEl.attr[1]` : an single attribute table (see below); useful for iterating all attributes of an element, or for disambiguating attributes with the same name in different namespaces
  * <strong>`someEl.kids`</strong> : an array table of child elements, text nodes, comment nodes, and processing instructions
  * <strong>`someEl.el`</strong> : an array table of child elements only
  * <strong>`someEl.parent`</strong> : reference to the parent element or document table
* **Attribute**
  * <strong>`someAttr.type`</strong> : the string `"attribute"`
  * <strong>`someAttr.name`</strong> : the name of the attribute (without any namespace prefix)
  * <strong>`someAttr.value`</strong> : the string value of the attribute (with XML and numeric entities unescaped)
  * <strong>`someAttr.nsURI`</strong> : the namespace URI for the attribute; `nil` if no namespace is applied
  * <strong>`someAttr.parent`</strong> : reference to the owning element table
* **Text** - for both CDATA and normal text nodes
  * <strong>`someText.type`</strong> : the string `"text"`
  * <strong>`someText.name`</strong> : the string `"#text"`
  * <strong>`someText.value`</strong> : the string content of the text node (with XML and numeric entities unescaped for non-CDATA elements)
  * <strong>`someText.parent`</strong> : reference to the parent element table
* **Comment**
  * <strong>`someComment.type`</strong> : the string `"comment"`
  * <strong>`someComment.name`</strong> : the string `"#comment"`
  * <strong>`someComment.value`</strong> : the string content of the attribute
  * <strong>`someComment.parent`</strong> : reference to the parent element or document table
* **Processing Instruction**
  * <strong>`someComment.type`</strong> : the string `"pi"`
  * <strong>`someComment.name`</strong> : the string name of the PI, e.g. `<?foo …?>` has a name of `"foo"`
  * <strong>`someComment.value`</strong> : the string content of the PI, i.e. everything but the name
  * <strong>`someComment.parent`</strong> : reference to the parent element or document table

### Finding Text for a DOM Element

The following function can be used to calculate the "inner text" for an element:

```lua
function elementText(el)
  local pieces = {}
  for _,n in ipairs(el.kids) do
    if n.type=='element' then pieces[#pieces+1] = elementText(n)
    elseif n.type=='text' then pieces[#pieces+1] = n.value
    end
  end
  return table.concat(pieces)
end

local xml  = [[<p>Hello <em>you crazy <b>World</b></em>!</p>]]
local para = SLAXML:dom(xml).root
print(elementText(para)) --> "Hello you crazy World!"
```

### A Simpler DOM

If you want the DOM tables to be simpler-to-serialize you can supply the `simple` option via:

```lua
local dom = SLAXML:dom(myXML,{ simple=true })
```

In this case no table will have a `parent` attribute, elements will not have the `el` collection, and the `attr` collection will be a simple array (without values accessible directly via attribute name). In short, the output will be a strict hierarchy with no internal references to other tables, and all data represented in exactly one spot.


## Known Limitations / TODO
- Does not require or enforce well-formed XML. Certain syntax errors are
  silently ignored and consumed. For example:
  - `foo="yes & no"` is seen as a valid attribute
  - `<foo></bar>` invokes `startElement("foo")`
    followed by `closeElement("bar")`
  - `<foo> 5 < 6 </foo>` is seen as valid text contents
- No support for custom entity expansion other than the standard XML
  entities (`&lt; &gt; &quot; &apos; &amp;`) and numeric entities
  (e.g. `&#10;` or `&#x3c;`)
- XML Declarations (`<?xml version="1.x"?>`) are incorrectly reported
  as Processing Instructions
- No support for DTDs
- No support for extended (Unicode) characters in element/attribute names
- No support for charset
- No support for [XInclude](http://www.w3.org/TR/xinclude/)
- Does not ensure that the reserved `xml` prefix is never redefined to an illegal namespace
- Does not ensure that the reserved `xmlns` prefix is never used as an element prefix


## History

### v0.7 2014-Sep-26
+ Decodes entities above 127 as UTF8 (decimal and hexadecimal).
  - The encoding specified by the document is (still) ignored.
    If you parse an XML file encoded in some other format, that
    intermixes 'raw' high-byte characters with high-byte entities,
    the result will be a broken encoding.

### v0.6.1 2014-Sep-25
+ Fixes Issue #6, adding support for ASCII hexadecimal entities (e.g. `&#x3c;`). (Thanks Leorex/Ben Bishop)

### v0.6 2014-Apr-18
+ Fixes Issue #5 (and more): Namespace prefixes defined on element are now properly applied to the element itself and any attributes using them when the definitions appear later in source than the prefix usage. (Thanks Oliver Kroth.)
+ The streaming parser now supplies the namespace prefix for elements and attributes.

### v0.5.3 2014-Feb-12
+ Fixes Issue #3: The [reserved `xml` prefix](http://www.w3.org/TR/xml-names/#ns-decl) may be used without pre-declaring it. (Thanks David Durkee.)

### v0.5.2 2013-Nov-7
+ Lua 5.2 compatible
+ Parser now errors if it finishes without finding a root element,
  or if there are unclosed elements at the end.
  (Proper element pairing is not enforced by the parser, but is—as
  in previous releases—enforced by the DOM builder.)

### v0.5.1 2013-Feb-18
+ `<foo xmlns="bar">` now directly generates `startElement("foo","bar")`
  with no post callback for `namespace` required.

### v0.5 2013-Feb-18
+ Use the `local SLAXML=require 'slaxml'` pattern to prevent any pollution
  of the global namespace.

### v0.4.3 2013-Feb-17
+ Bugfix to allow empty attributes, i.e. `foo=""`
+ `closeElement` no longer includes namespace prefix in the name, includes the nsURI

### v0.4 2013-Feb-16
+ DOM adds `.parent` references
+ `SLAXML.ignoreWhitespace` is now `:parse(xml,{stripWhitespace=true})`
+ "simple" mode for DOM parsing

### v0.3 2013-Feb-15
+ Support namespaces for elements and attributes
  + `<foo xmlns="barURI">` will call `startElement("foo",nil)` followed by
    `namespace("barURI")` (and then `attribute("xmlns","barURI",nil)`);
    you must apply the namespace to your element after creation.
  + Child elements without a namespace prefix that inherit a namespace will
    receive `startElement("child","barURI")`
  + `<xy:foo>` will call `startElement("foo","uri-for-xy")`
  + `<foo xy:bar="yay">` will call `attribute("bar","yay","uri-for-xy")`
  + Runtime errors are generated for any namespace prefix that cannot be resolved
+ Add (optional) DOM parser that validates hierarchy and supports namespaces

### v0.2 2013-Feb-15
+ Supports expanding numeric entities e.g. `&#34;` -> `"`
+ Utility functions are local to parsing (not spamming the global namespace)

### v0.1 2013-Feb-7
+ Option to ignore whitespace-only text nodes
+ Supports unescaped > in attributes
+ Supports CDATA
+ Supports Comments
+ Supports Processing Instructions


## License
Copyright © 2013 [Gavin Kistner](mailto:!@phrogz.net)

Licensed under the [MIT License](http://opensource.org/licenses/MIT). See LICENSE.txt for more details.
