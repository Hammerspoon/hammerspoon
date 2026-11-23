-- Fakes just enough of an hs.axuielement object for hs.spaces' Mission Control lookup:
-- field access for attributes and attributeValue("AXChildren"), which, like the real thing, returns a new
-- table on each call (hs.spaces consumes it with table.remove).
local function fakeElement(identifier, children)
  return {
    AXIdentifier   = identifier,
    AXChildren     = children or {},
    attributeValue = function(self, name)
      local value = rawget(self, name)
      if type(value) == "table" then value = table.move(value, 1, #value, 1, {}) end
      return value
    end,
  }
end

local function fakeDisplay(displayID, children)
  local display = fakeElement("mc.display", children)
  display.AXDisplayID = displayID
  return display
end

local function fakeSpacesBar()
  return fakeElement("mc.spaces", {
    fakeElement("mc.spaces.list", { fakeElement(nil), fakeElement(nil) }),
    fakeElement("mc.spaces.add"),
  })
end

function testMissionControlGroupInDock()
  local mcGroup = fakeElement("mc", { fakeElement("mc.display") })
  local dock = fakeElement(nil, { fakeElement(nil), mcGroup })
  local windowManager = fakeElement(nil, {})

  assertIsEqual(mcGroup, hs.spaces._missionControlGroupFrom(dock, windowManager))
  return success()
end

function testMissionControlGroupInWindowManager()
  -- macOS 27: the Dock only keeps an empty `mc` stub, the tree lives in WindowManager
  local dock = fakeElement(nil, { fakeElement(nil), fakeElement("mc") })
  local windowManager = fakeElement(nil, { fakeElement("mc.display"), fakeElement("mc.display") })

  assertIsEqual(windowManager, hs.spaces._missionControlGroupFrom(dock, windowManager))
  return success()
end

function testMissionControlGroupNotPopulated()
  -- Mission Control is showing but its tree is not built yet: keep waiting rather than return the stub
  local dock = fakeElement(nil, { fakeElement("mc") })
  local windowManager = fakeElement(nil, {})

  assertIsNil(hs.spaces._missionControlGroupFrom(dock, windowManager))
  return success()
end

function testMissionControlGroupClosed()
  local dock = fakeElement(nil, { fakeElement(nil) })
  local windowManager = fakeElement(nil, {})

  assertIsNil(hs.spaces._missionControlGroupFrom(dock, windowManager))
  assertIsNil(hs.spaces._missionControlGroupFrom(dock, nil))
  return success()
end

function testSpacesSubgroupFound()
  -- macOS 27: the `mc.display` groups are children of the WindowManager application element
  local spacesBar = fakeSpacesBar()
  local windowManager = fakeElement(nil, { fakeDisplay(1, { fakeElement(nil), spacesBar }), fakeDisplay(4, { fakeSpacesBar() }) })

  assertIsEqual(spacesBar.AXChildren[1], hs.spaces._spacesSubgroupFrom(windowManager, "mc.spaces.list", 1))
  assertIsEqual(spacesBar.AXChildren[2], hs.spaces._spacesSubgroupFrom(windowManager, "mc.spaces.add", 1))
  return success()
end

function testSpacesSubgroupPartialTree()
  -- Mission Control reopened right after being closed: WindowManager briefly shows only part of the tree, which
  -- findSpacesSubgroup retries instead of returning these errors straight away
  local windowManager = fakeElement(nil, { fakeDisplay(1, { fakeElement(nil) }) })

  local result, errMsg = hs.spaces._spacesSubgroupFrom(windowManager, "mc.spaces.list", 4)
  assertIsNil(result)
  assertIsEqual("no display with specified id found", errMsg)

  result, errMsg = hs.spaces._spacesSubgroupFrom(windowManager, "mc.spaces.list", 1)
  assertIsNil(result)
  assertIsEqual("unable to locate mc.spaces group for display", errMsg)

  result, errMsg = hs.spaces._spacesSubgroupFrom(nil, "mc.spaces.list", 1)
  assertIsNil(result)
  assertIsEqual("unable to get Mission Control data from the Dock", errMsg)
  return success()
end

function testSpacesNameFromButtonName()
  -- macOS 27's WindowManager uses these English templates whatever the user's language
  assertIsEqual("Desktop", hs.spaces._spacesNameFromButtonName("exit to Desktop"))
  assertIsEqual("Desktop 2", hs.spaces._spacesNameFromButtonName("exit to Desktop 2"))
  assertIsEqual("Safari", hs.spaces._spacesNameFromButtonName("exit to full screen Safari"))
  assertIsEqual("Something else", hs.spaces._spacesNameFromButtonName("Something else"))
  return success()
end
