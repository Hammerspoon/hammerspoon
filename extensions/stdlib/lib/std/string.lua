--[[--
 Additions to the core string module.

 The module table returned by `std.string` also contains all of the entries
 from the core string table.  An hygienic way to import this module, then, is
 simply to override the core `string` locally:

    local string = require "std.string"

 @corelibrary std.string
]]


local assert		= assert
local getmetatable	= getmetatable
local string		= string
local tonumber		= tonumber
local tostring		= tostring
local type		= type

local io_stderr		= io.stderr
local math_abs		= math.abs
local math_floor	= math.floor
local table_concat	= table.concat
local table_insert	= table.insert
local string_format	= string.format


local _			= require "std._base"

local _tostring		= _.tostring
local argscheck		= _.typecheck and _.std.typecheck.argscheck
local copy		= _.base.copy
local escape_pattern	= _.string.escape_pattern
local len		= _.operator.len
local merge		= _.base.merge
local render		= _.string.render
local sortkeys		= _.base.sortkeys
local split		= _.string.split

local _ENV		= _.strict and _.strict {} or _ENV

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local M


local function __concat (s, o)
  return _tostring (s) .. _tostring (o)
end


local function __index (s, i)
  if type (i) == "number" then
    return s:sub (i, i)
  else
    -- Fall back to module metamethods
    return M[i]
  end
end


local _format = string.format

local function format (f, arg1, ...)
  return (arg1 ~= nil) and _format (f, arg1, ...) or f
end


local function tpack (from, to, ...)
  return from, to, {...}
end

local function tfind (s, ...)
  return tpack (s:find (...))
end


local function finds (s, p, i, ...)
  i = i or 1
  local l = {}
  local from, to, r
  repeat
    from, to, r = tfind (s, p, i, ...)
    if from ~= nil then
      table_insert (l, {from, to, capt = r})
      i = to + 1
    end
  until not from
  return l
end


local function caps (s)
  return (s:gsub ("(%w)([%w]*)", function (l, ls) return l:upper () .. ls end))
end


local function escape_shell (s)
  return (s:gsub ("([ %(%)%\\%[%]\"'])", "\\%1"))
end


local function ordinal_suffix (n)
  n = math_abs (n) % 100
  local d = n % 10
  if d == 1 and n ~= 11 then
    return "st"
  elseif d == 2 and n ~= 12 then
    return "nd"
  elseif d == 3 and n ~= 13 then
    return "rd"
  else
    return "th"
  end
end


local function pad (s, w, p)
  p = string.rep (p or " ", math_abs (w))
  if w < 0 then
    return string.sub (p .. s, w)
  end
  return string.sub (s .. p, 1, w)
end


local function wrap (s, w, ind, ind1)
  w = w or 78
  ind = ind or 0
  ind1 = ind1 or ind
  assert (ind1 < w and ind < w,
          "the indents must be less than the line width")
  local r = { string.rep (" ", ind1) }
  local i, lstart, lens = 1, ind1, len (s)
  while i <= lens do
    local j = i + w - lstart
    while len (s[j]) > 0 and s[j] ~= " " and j > i do
      j = j - 1
    end
    local ni = j + 1
    while s[j] == " " do
      j = j - 1
    end
    table_insert (r, s:sub (i, j))
    i = ni
    if i < lens then
      table_insert (r, "\n" .. string.rep (" ", ind))
      lstart = ind
    end
  end
  return table_concat (r)
end


local function numbertosi (n)
  local SIprefix = {
    [-8] = "y", [-7] = "z", [-6] = "a", [-5] = "f",
    [-4] = "p", [-3] = "n", [-2] = "mu", [-1] = "m",
    [0] = "", [1] = "k", [2] = "M", [3] = "G",
    [4] = "T", [5] = "P", [6] = "E", [7] = "Z",
    [8] = "Y"
  }
  local t = _format ("% #.2e", n)
  local _, _, m, e = t:find(".(.%...)e(.+)")
  local man, exp = tonumber (m), tonumber (e)
  local siexp = math_floor (exp / 3)
  local shift = exp - siexp * 3
  local s = SIprefix[siexp] or "e" .. tostring (siexp)
  man = man * (10 ^ shift)
  return _format ("%0.f", man) .. s
end


local function prettytostring (x, indent, spacing)
  indent = indent or "\t"
  spacing = spacing or ""
  return render (x, {
    open = function ()
      local s = spacing .. "{"
      spacing = spacing .. indent
      return s
    end,

    close = function ()
      spacing = string.gsub (spacing, indent .. "$", "")
      return spacing .. "}"
    end,

    elem = function (x)
      if type (x) ~= "string" then return tostring (x) end
      return string_format ("%q", x)
    end,

    pair = function (x, _, _, k, v, kstr, vstr)
      local type_k = type (k)
      local s = spacing
      if type_k ~= "string" or k:match "[^%w_]" then
        s = s .. "["
        if type_k == "table" then
          s = s .. "\n"
        end
        s = s .. kstr
        if type_k == "table" then
          s = s .. "\n"
        end
        s = s .. "]"
      else
        s = s .. k
      end
      s = s .. " ="
      if type (v) == "table" then
        s = s .. "\n"
      else
        s = s .. " "
      end
      s = s .. vstr
      return s
    end,

    sep = function (_, k)
      local s = "\n"
      if k then
        s = "," .. s
      end
      return s
    end,

    sort = sortkeys,
  })
end


local function trim (s, r)
  r = r or "%s+"
  return (s:gsub ("^" .. r, ""):gsub (r .. "$", ""))
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local function X (decl, fn)
  return argscheck and argscheck ("std.string." .. decl, fn) or fn
end

M = {
  --- Metamethods
  -- @section metamethods

  --- String concatenation operation.
  -- @function __concat
  -- @string s initial string
  -- @param o object to stringify and concatenate
  -- @return s .. tostring (o)
  -- @usage
  -- local string = setmetatable ("", require "std.string")
  -- concatenated = "foo" .. {"bar"}
  __concat = __concat,

  --- String subscript operation.
  -- @function __index
  -- @string s string
  -- @tparam int|string i index or method name
  -- @return `s:sub (i, i)` if i is a number, otherwise
  --   fall back to a `std.string` metamethod (if any).
  -- @usage
  -- getmetatable ("").__index = require "std.string".__index
  -- third = ("12345")[3]
  __index = __index,


  --- Core Functions
  -- @section corefuncs

  --- Capitalise each word in a string.
  -- @function caps
  -- @string s any string
  -- @treturn string *s* with each word capitalized
  -- @usage userfullname = caps (input_string)
  caps = X ("caps (string)", caps),

  --- Remove any final newline from a string.
  -- @function chomp
  -- @string s any string
  -- @treturn string *s* with any single trailing newline removed
  -- @usage line = chomp (line)
  chomp = X ("chomp (string)", function (s) return (s:gsub ("\n$", "")) end),

  --- Escape a string to be used as a pattern.
  -- @function escape_pattern
  -- @string s any string
  -- @treturn string *s* with active pattern characters escaped
  -- @usage substr = inputstr:match (escape_pattern (literal))
  escape_pattern = X ("escape_pattern (string)", escape_pattern),

  --- Escape a string to be used as a shell token.
  -- Quotes spaces, parentheses, brackets, quotes, apostrophes and
  -- whitespace.
  -- @function escape_shell
  -- @string s any string
  -- @treturn string *s* with active shell characters escaped
  -- @usage os.execute ("echo " .. escape_shell (outputstr))
  escape_shell = X ("escape_shell (string)", escape_shell),

  --- Repeatedly `string.find` until target string is exhausted.
  -- @function finds
  -- @string s target string
  -- @string pattern pattern to match in *s*
  -- @int[opt=1] init start position
  -- @bool[opt] plain inhibit magic characters
  -- @return list of `{from, to; capt = {captures}}`
  -- @see std.string.tfind
  -- @usage
  -- for t in std.elems (finds ("the target string", "%S+")) do
  --   print (tostring (t.capt))
  -- end
  finds = X ("finds (string, string, ?int, ?boolean|:plain)", finds),

  --- Extend to work better with one argument.
  -- If only one argument is passed, no formatting is attempted.
  -- @function format
  -- @string f format string
  -- @param[opt] ... arguments to format
  -- @return formatted string
  -- @usage print (format "100% stdlib!")
  format = X ("format (string, [any...])", format),

  --- Remove leading matter from a string.
  -- @function ltrim
  -- @string s any string
  -- @string[opt="%s+"] r leading pattern
  -- @treturn string *s* with leading *r* stripped
  -- @usage print ("got: " .. ltrim (userinput))
  ltrim = X ("ltrim (string, ?string)",
             function (s, r) return (s:gsub ("^" .. (r or "%s+"), "")) end),

  --- Write a number using SI suffixes.
  -- The number is always written to 3 s.f.
  -- @function numbertosi
  -- @tparam number|string n any numeric value
  -- @treturn string *n* simplifed using largest available SI suffix.
  -- @usage print (numbertosi (bitspersecond) .. "bps")
  numbertosi = X ("numbertosi (number|string)", numbertosi),

  --- Return the English suffix for an ordinal.
  -- @function ordinal_suffix
  -- @tparam int|string n any integer value
  -- @treturn string English suffix for *n*
  -- @usage
  -- local now = os.date "*t"
  -- print ("%d%s day of the week", now.day, ordinal_suffix (now.day))
  ordinal_suffix = X ("ordinal_suffix (int|string)", ordinal_suffix),

  --- Justify a string.
  -- When the string is longer than w, it is truncated (left or right
  -- according to the sign of w).
  -- @function pad
  -- @string s a string to justify
  -- @int w width to justify to (-ve means right-justify; +ve means
  --   left-justify)
  -- @string[opt=" "] p string to pad with
  -- @treturn string *s* justified to *w* characters wide
  -- @usage print (pad (trim (outputstr, 78)) .. "\n")
  pad = X ("pad (string, int, ?string)", pad),

  --- Pretty-print a table, or other object.
  -- @function prettytostring
  -- @param x object to convert to string
  -- @string[opt="\t"] indent indent between levels
  -- @string[opt=""] spacing space before every line
  -- @treturn string pretty string rendering of *x*
  -- @usage print (prettytostring (std, "  "))
  prettytostring = X ("prettytostring (?any, ?string, ?string)", prettytostring),

  --- Turn tables into strings with recursion detection.
  -- N.B. Functions calling render should not recurse, or recursion
  -- detection will not work.
  -- @function render
  -- @param x object to convert to string
  -- @tparam[opt] rendercbs fns default rendering function overrides
  -- @return string representation of *x*
  -- @usage
  -- function tostablestring (x)
  --   return render (x, {
  --     sort = function (keys)
  --       table.sort (keys, lambda "=tostring (_1) < tostring (_2)")
  --       return keys
  --     end,
  --   })
  -- end
  render = X ("render (?any, ?table)", function (x, rendercbs, roots)
      return render (x, rendercbs, roots)
    end
  ),

  --- Remove trailing matter from a string.
  -- @function rtrim
  -- @string s any string
  -- @string[opt="%s+"] r trailing pattern
  -- @treturn string *s* with trailing *r* stripped
  -- @usage print ("got: " .. rtrim (userinput))
  rtrim = X ("rtrim (string, ?string)",
             function (s, r) return (s:gsub ((r or "%s+") .. "$", "")) end),

  --- Split a string at a given separator.
  -- Separator is a Lua pattern, so you have to escape active characters,
  -- `^$()%.[]*+-?` with a `%` prefix to match a literal character in *s*.
  -- @function split
  -- @string s to split
  -- @string[opt="%s+"] sep separator pattern
  -- @return list of strings
  -- @usage words = split "a very short sentence"
  split = X ("split (string, ?string)", split),

  --- Do `string.find`, returning a table of captures.
  -- @function tfind
  -- @string s target string
  -- @string pattern pattern to match in *s*
  -- @int[opt=1] init start position
  -- @bool[opt] plain inhibit magic characters
  -- @treturn int start of match
  -- @treturn int end of match
  -- @treturn table list of captured strings
  -- @see std.string.finds
  -- @usage b, e, captures = tfind ("the target string", "%s", 10)
  tfind = X ("tfind (string, string, ?int, ?boolean|:plain)", tfind),

  --- Remove leading and trailing matter from a string.
  -- @function trim
  -- @string s any string
  -- @string[opt="%s+"] r trailing pattern
  -- @treturn string *s* with leading and trailing *r* stripped
  -- @usage print ("got: " .. trim (userinput))
  trim = X ("trim (string, ?string)", trim),

  --- Wrap a string into a paragraph.
  -- @function wrap
  -- @string s a paragraph of text
  -- @int[opt=78] w width to wrap to
  -- @int[opt=0] ind indent
  -- @int[opt=ind] ind1 indent of first line
  -- @treturn string *s* wrapped to *w* columns
  -- @usage
  -- print (wrap (copyright, 72, 4))
  wrap = X ("wrap (string, ?int, ?int, ?int)", wrap),
}


return merge (M, string)



--- Types
-- @section Types

--- Table of default render callback functions.
-- @table rendercbs
-- @tfield[opt] opentablecb open open table rendering function
-- @tfield[opt] closetablecb close close table rendering function
-- @tfield[opt] elementcb elem element rendering function
-- @tfield[opt] paircb pair pair rendering function
-- @tfield[opt] separatorcb sep separator rendering function
-- @tfield[opt] sortcb sort key sorting function
-- @tfield[opt] termcb term terminal predicate
-- @see render
-- @usage
-- function tostringstable (x)
--   return render (x, { sort = some_sequence_reordering_fn })
-- end


--- Signature of @{render} open table callback.
-- @function opentablecb
-- @tparam table t table about to be rendered
-- @treturn string open table rendering
-- @see render
-- @usage function open (t) return "{" end


--- Signature of @{render} close table callback.
-- @function closetablecb
-- @tparam table t table just rendered
-- @treturn string close table rendering
-- @see render
-- @usage function close (t) return "}" end


--- Signature of @{render} element callback.
-- @function elementcb
-- @param x element to render
-- @treturn string element rendering
-- @see render
-- @usage function element (e) return require "std".tostring (e) end


--- Signature of @{render} pair callback.
-- Trying to re-render *key* or *value* here will break recursion
-- detection, use *strkey* and *strvalue* pre-rendered values instead.
-- @function paircb
-- @tparam table t table containing pair being rendered
-- @param key key part of key being rendered
-- @param value value part of key being rendered
-- @string keystr prerendered *key*
-- @string valuestr prerendered *value*
-- @treturn string pair rendering
-- @see render
-- @usage
-- function pair (_, _, _, key, value) return key .. "=" .. value end


--- Signature of @{render} separator callback.
-- @function separatorcb
-- @tparam table t table currently being rendered
-- @param pk *t* key preceding separator, or `nil` for first key
-- @param pv *t* value preceding separator, or `nil` for first value
-- @param fk *t* key following separator, or `nil` for last key
-- @param fv *t* value following separator, or `nil` for last value
-- @treturn string separator rendering
-- @usage
-- function separator (_, _, _, fk) return fk and "," or "" end


--- Signature of @{render} key sorting callback.
-- @function sortcb
-- @tparam sequence keys all keys from rendering table
-- @treturn sequence *keys* in desired display order
-- @usage
-- function unsorted (keys) return keys end


--- Signature of @{render} terminal predicate callback.
-- @function termcb
-- @param x an element to be rendered
-- @treturn boolean whether *x* can be rendered by @{elementcb}
-- @usage
-- function term (x)
--   return type (x) ~= "table" or getmetamethod (x, "__tostring")
-- end
