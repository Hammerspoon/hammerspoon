--[[
 Return a table of debug parameters.

 Before loading this module, set the global `_DEBUG` according to what
 debugging features you wish to use until the application exits.
]]


local function choose (t)
  for k, v in pairs (t) do
    if _DEBUG == false then
      t[k] = v.fast
    elseif _DEBUG == nil then
      t[k] = v.default
    elseif type(_DEBUG) ~= "table" then
      t[k] = v.safe
    elseif _DEBUG[k] ~= nil then
      t[k] = _DEBUG[k]
    else
      t[k] = v.default
    end
  end
  return t
end


return {
  _DEBUG = choose {
    argcheck  = { default = true,  safe = true,   fast = false},
    call      = { default = false, safe = false,  fast = false},
    deprecate = { default = nil,   safe = true,   fast = false},
    level     = { default = 1,     safe = 1,      fast = math.huge},
    strict    = { default = true,  safe = true,   fast = false},
  },
}
