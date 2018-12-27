-- hs.inspect tests
hs.inspect = require("hs.inspect")

function testSimpleInspect()
    local t = {a='b'}
    assertIsEqual([[{
  a = "b"
}]], hs.inspect(t))
    return success()
end

-- tests the case where a custom __init always returns a new table instance as a key/value
function testInspectAlwaysNewTableKeyValue()
  local t = setmetatable({}, {
    __init = function(_, _)
      return {}
    end,
    __pairs = function(self)
      local function stateless_iter(_, k)
        if k ~= "a" then
          return "a", "b"
        end
      end
      -- Return an iterator function, the table, starting point
    return stateless_iter, self, nil
    end,
  })

  assertIsEqual('{a = "b"}', hs.inspect(t))

  return success()
end
