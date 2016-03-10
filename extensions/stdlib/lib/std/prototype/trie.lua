--[[--
 Trie Prototype.

 This module returns a table of trie operators, as well as the prototype
 for a Trie container object.

 This is not a search tree, but rather a radix tree to efficiently store
 and retrieve values stored with a path as a key, such as a multi-key
 keytable.  Although it does have iterators for walking the trie with
 various algorithms.

 In addition to the functionality described here, Trie containers also
 have all the methods and metamethods of the @{prototype.container.prototype}
 (except where overridden here),

 Prototype Chain
 ---------------

      table
       `-> Container
            `-> Trie

 @module std.prototype.trie
]]


local getmetatable	= getmetatable
local rawget		= rawget
local rawset		= rawset
local setmetatable	= setmetatable
local type		= type

local coroutine_wrap	= coroutine.wrap
local coroutine_yield	= coroutine.yield
local table_remove	= table.remove


local Container		= require "std.prototype.container".prototype
local _			= require "std.prototype._base"

local Module		= _.Module
local argscheck		= _.typecheck and _.typecheck.argscheck
local ipairs		= _.ipairs
local len		= _.len
local pairs		= _.pairs

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function _nodes (it, tr)
  local p = {}
  local function visit (n)
    if type (n) == "table" then
      coroutine_yield ("branch", p, n)
      for i, v in it (n) do
        p[#p + 1] = i
        visit (v)
        table_remove (p)
      end
      coroutine_yield ("join", p, n)
    else
      coroutine_yield ("leaf", p, n)
    end
  end
  return coroutine_wrap (visit), tr
end


local function clone (t, nometa)
  local r = {}
  if not nometa then
    setmetatable (r, getmetatable (t))
  end
  local d = {[t] = r}
  local function copy (o, x)
    for i, v in pairs (x) do
      if type (v) == "table" then
        if not d[v] then
          d[v] = {}
          if not nometa then
            setmetatable (d[v], getmetatable (v))
          end
          o[i] = copy (d[v], v)
        else
          o[i] = d[v]
        end
      else
        o[i] = v
      end
    end
    return o
  end
  return copy (r, t)
end


local function leaves (it, tr)
  local function visit (n)
    if type (n) == "table" then
      for _, v in it (n) do
        visit (v)
      end
    else
      coroutine_yield (n)
    end
  end
  return coroutine_wrap (visit), tr
end


local function merge (t, u)
  for ty, p, n in _nodes (pairs, u) do
    if ty == "leaf" then
      t[p] = n
    end
  end
  return t
end



--[[ ============ ]]--
--[[ Trie Object. ]]--
--[[ ============ ]]--


local function X (decl, fn)
  return argscheck and argscheck ("std.prototype.trie." .. decl, fn) or fn
end


--- Return the object type, if set, otherwise the Lua type.
-- @param x item to act on
-- @treturn string object type of *x*, otherwise `type (x)`
local function _type (x)
  return (getmetatable (x) or {})._type or type (x)
end


--- Trie prototype object.
-- @object prototype
-- @string[opt="Trie"] _type object name
-- @see prototype.container.prototype
-- @usage
-- local trie = require "std.prototype.trie"
-- local Trie = trie.prototype
-- local tr = Trie {}
-- tr[{"branch1", 1}] = "leaf1"
-- tr[{"branch1", 2}] = "leaf2"
-- tr[{"branch2", 1}] = "leaf3"
-- print (tr[{"branch1"}])      --> Trie {leaf1, leaf2}
-- print (tr[{"branch1", 2}])   --> leaf2
-- print (tr[{"branch1", 3}])   --> nil
-- --> leaf1	leaf2	leaf3
-- for leaf in trie.leaves (tr) do
--   io.write (leaf .. "\t")
-- end

local Trie

Trie = Container {
  _type = "Trie",

  --- Metamethods
  -- @section metamethods

  --- Deep retrieval.
  -- @function prototype:__index
  -- @param i non-table, or list of keys `{i1, ...i_n}`
  -- @return `tr[i1]...[i_n]` if *i* is a key list, `tr[i]` otherwise
  -- @todo the following doesn't treat list keys correctly
  --       e.g. tr[{{1, 2}, {3, 4}}], maybe flatten first?
  -- @usage
  -- del_other_window = keymap[{"C-x", "4", KEY_DELETE}]
  __index = function (tr, i)
    if _type (i) == "table" then
      local r = tr
      for _, v in ipairs (i) do
	if r == nil then return nil end
        r = r[v]
      end
      return r
    else
      return rawget (tr, i)
    end
  end,

  --- Deep insertion.
  -- @function prototype:__newindex
  -- @param i non-table, or list of keys `{i1, ...i_n}`
  -- @param[opt] v value
  -- @usage
  -- function bindkey (keylist, fn) keymap[keylist] = fn end
  __newindex = function (tr, i, v)
    if _type (i) == "table" then
      for n = 1, len (i) - 1 do
        if _type (tr[i[n]]) ~= "Trie" then
          rawset (tr, i[n], Trie {})
        end
        tr = tr[i[n]]
      end
      rawset (tr, i[len(i)], v)
    else
      rawset (tr, i, v)
    end
  end,
}


return Module {
  prototype = Trie,

  --- Module Functions
  -- @section modulefunctions

  --- Make a deep copy of a trie or table, including any metatables.
  -- @function clone
  -- @tparam table tr trie or trie-like table
  -- @tparam boolean nometa if non-`nil` don't copy metatables
  -- @treturn prototype|table a deep copy of *tr*
  -- @see prototype.object.clone
  -- @usage
  -- tr = {"one", {two=2}, {{"three"}, four=4}}
  -- copy = clone (tr)
  -- copy[2].two=5
  -- assert (tr[2].two == 2)
  clone = X ("clone (table, ?boolean|:nometa)", clone),

  --- Trie iterator which returns just numbered leaves, in order.
  -- @function ileaves
  -- @tparam prototype|table tr trie or trie-like table
  -- @treturn function iterator function
  -- @treturn prototype|table the trie *tr*
  -- @see inodes
  -- @see leaves
  -- @usage
  -- --> t = {"one", "three", "five"}
  -- for leaf in ileaves {"one", {two=2}, {{"three"}, four=4}}, foo="bar", "five"}
  -- do
  --   t[#t + 1] = leaf
  -- end
  ileaves = X ("ileaves (table)", function (t) return leaves (ipairs, t) end),

  --- Trie iterator over numbered nodes, in order.
  --
  -- The iterator function behaves like @{nodes}, but only traverses the
  -- array part of the nodes of *tr*, ignoring any others.
  -- @function inodes
  -- @tparam prototype|table tr trie or trie-like table to iterate over
  -- @treturn function iterator function
  -- @treturn trie|table the trie, *tr*
  -- @see nodes
  inodes = X ("inodes (table)", function (t) return _nodes (ipairs, t) end),

  --- Trie iterator which returns just leaves.
  -- @function leaves
  -- @tparam table t trie or trie-like table
  -- @treturn function iterator function
  -- @treturn table *t*
  -- @see ileaves
  -- @see nodes
  -- @usage
  -- for leaf in leaves {"one", {two=2}, {{"three"}, four=4}}, foo="bar", "five"}
  -- do
  --   t[#t + 1] = leaf
  -- end
  -- --> t = {2, 4, "five", "foo", "one", "three"}
  -- table.sort (t, lambda "=tostring(_1) < tostring(_2)")
  leaves = X ("leaves (table)", function (t) return leaves (pairs, t) end),

  --- Destructively deep-merge one trie into another.
  -- @function merge
  -- @tparam table t destination trie
  -- @tparam table u table with nodes to merge
  -- @treturn table *t* with nodes from *u* merged in
  -- @usage
  -- merge (dest, {{exists=1}, {{not = {present = { inside = "dest" }}}}})
  merge = X ("merge (table, table)", merge),

  --- Trie iterator over all nodes.
  --
  -- The returned iterator function performs a depth-first traversal of
  -- `tr`, and at each node it returns `{node-type, trie-path, trie-node}`
  -- where `node-type` is `branch`, `join` or `leaf`; `trie-path` is a
  -- list of keys used to reach this node, and `trie-node` is the current
  -- node.
  --
  -- Note that the `trie-path` reuses the same table on each iteration, so
  -- you must `table.clone` a copy if you want to take a snap-shot of the
  -- current state of the `trie-path` list before the next iteration
  -- changes it.
  -- @function nodes
  -- @tparam prototype|table tr trie or trie-like table to iterate over
  -- @treturn function iterator function
  -- @treturn prototype|table the trie, *tr*
  -- @see inodes
  -- @usage
  -- -- trie = +-- node1
  -- --        |    +-- leaf1
  -- --        |    '-- leaf2
  -- --        '-- leaf 3
  -- trie = Trie { Trie { "leaf1", "leaf2"}, "leaf3" }
  -- for node_type, path, node in nodes (trie) do
  --   print (node_type, path, node)
  -- end
  -- --> "branch"   {}      {{"leaf1", "leaf2"}, "leaf3"}
  -- --> "branch"   {1}     {"leaf1", "leaf2")
  -- --> "leaf"     {1,1}   "leaf1"
  -- --> "leaf"     {1,2}   "leaf2"
  -- --> "join"     {1}     {"leaf1", "leaf2"}
  -- --> "leaf"     {2}     "leaf3"
  -- --> "join"     {}      {{"leaf1", "leaf2"}, "leaf3"}
  -- os.exit (0)
  nodes = X ("nodes (table)", function (t) return _nodes (pairs, t) end),
}
