--- === hs.razer ===
---
--- Razer device support.
---
--- This module allows you to control the LEDs on 130 Razer peripherals.
--- It also allows you to trigger a callback on button presses on a Razer Tartarus V2.
---
--- This extension was thrown together by [Chris Hocking](https://github.com/latenitefilms).
---
--- Special thanks to the [librazermacos](https://github.com/1kc/librazermacos) project,
--- which is a C library of [OpenRazer](https://github.com/openrazer/openrazer) drivers ported to macOS.
---
--- Example usage with a Razer Tartarus V2:
--- ```lua
--- deviceId = hs.razer.devices()[1].internalDeviceId
--- device = hs.razer.new(deviceId)
--- if device then
---   print(string.format("Device Connected: %s", device:deviceName()))
---   if device:productId() == 0x022b then
---     print("Disabling Default Button Layout...")
---     device:disableDefaultButtonLayout()
---   end
---   print("Setting up a callback...")
---   device:callback(function(obj, msg, buttonName, buttonAction)
---     print(string.format("obj: %s, msg: %s, buttonName: %s, buttonAction: %s", obj, msg, buttonName, buttonAction))
---   end)
--- end
--- ```

--[[
TEST CODE FOR RAZER TARTARUS V2:

deviceId = hs.razer.devices()[1].internalDeviceId
device = hs.razer.new(deviceId)
if device then
  print(string.format("Device Connected: %s", device:deviceName()))
  if device:productId() == 0x022b then
    print("Disabling Default Button Layout...")
    device:disableDefaultButtonLayout()
  end
  print("Setting up a callback...")
  device:callback(function(obj, msg, buttonName, buttonAction)
    print(string.format("obj: %s, msg: %s, buttonName: %s, buttonAction: %s", obj, msg, buttonName, buttonAction))
  end)
end
--]]

local razer = require("hs.razer.internal")

local log = require "hs.logger".new("razer")

local razerObject = hs.getObjectMetatable("hs.razer")

-- RAZER_TARTARUS_V2_PRODUCT_ID -> number
-- Constant
-- Razer Tartarus V2 Product ID.
local RAZER_TARTARUS_V2_PRODUCT_ID = 0x022b

--- hs.razer:disableDefaultButtonLayout() -> none
--- Function
--- Remap the buttons on a Razer Tartarus V2 so they don't trigger their factory default shortcut keys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function razerObject:disableDefaultButtonLayout()
  if not self:productId() == RAZER_TARTARUS_V2_PRODUCT_ID then
    log.ef("Currently only the Razer Tartarus V2 is supported.")
    return
  end

  local command = [[hidutil property --matching '{"ProductID":]] .. string.format("0x%04x", RAZER_TARTARUS_V2_PRODUCT_ID) .. [[}' --set '{"UserKeyMapping":
   [{"HIDKeyboardModifierMappingSrc":0x70000001E,
     "HIDKeyboardModifierMappingDst":0x100000001
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001F,
     "HIDKeyboardModifierMappingDst":0x100000002
   },
   {"HIDKeyboardModifierMappingSrc":0x700000020,
     "HIDKeyboardModifierMappingDst":0x100000003
   },
   {"HIDKeyboardModifierMappingSrc":0x700000021,
     "HIDKeyboardModifierMappingDst":0x100000004
   },
   {"HIDKeyboardModifierMappingSrc":0x700000022,
     "HIDKeyboardModifierMappingDst":0x100000005
   },
   {"HIDKeyboardModifierMappingSrc":0x70000002B,
     "HIDKeyboardModifierMappingDst":0x100000006
   },
   {"HIDKeyboardModifierMappingSrc":0x700000014,
     "HIDKeyboardModifierMappingDst":0x100000007
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001A,
     "HIDKeyboardModifierMappingDst":0x100000008
   },
   {"HIDKeyboardModifierMappingSrc":0x700000008,
     "HIDKeyboardModifierMappingDst":0x100000009
   },
   {"HIDKeyboardModifierMappingSrc":0x700000015,
     "HIDKeyboardModifierMappingDst":0x100000010
   },
   {"HIDKeyboardModifierMappingSrc":0x700000039,
     "HIDKeyboardModifierMappingDst":0x100000011
   },
   {"HIDKeyboardModifierMappingSrc":0x700000004,
     "HIDKeyboardModifierMappingDst":0x100000012
   },
   {"HIDKeyboardModifierMappingSrc":0x700000016,
     "HIDKeyboardModifierMappingDst":0x100000013
   },
   {"HIDKeyboardModifierMappingSrc":0x700000007,
     "HIDKeyboardModifierMappingDst":0x100000014
   },
   {"HIDKeyboardModifierMappingSrc":0x700000009,
     "HIDKeyboardModifierMappingDst":0x100000015
   },
   {"HIDKeyboardModifierMappingSrc":0x7000000E1,
     "HIDKeyboardModifierMappingDst":0x100000016
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001D,
     "HIDKeyboardModifierMappingDst":0x100000017
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001B,
     "HIDKeyboardModifierMappingDst":0x100000018
   },
   {"HIDKeyboardModifierMappingSrc":0x700000006,
     "HIDKeyboardModifierMappingDst":0x100000019
   },
   {"HIDKeyboardModifierMappingSrc":0x70000002C,
     "HIDKeyboardModifierMappingDst":0x100000020
   },
   {"HIDKeyboardModifierMappingSrc":0x700000035,
     "HIDKeyboardModifierMappingDst":0x100000021
   },
   {"HIDKeyboardModifierMappingSrc":0x700000052,
     "HIDKeyboardModifierMappingDst":0x100000022
   },
   {"HIDKeyboardModifierMappingSrc":0x700000051,
     "HIDKeyboardModifierMappingDst":0x100000023
   },
   {"HIDKeyboardModifierMappingSrc":0x700000050,
     "HIDKeyboardModifierMappingDst":0x100000024
   },
   {"HIDKeyboardModifierMappingSrc":0x70000004F,
     "HIDKeyboardModifierMappingDst":0x100000025
   }
   ]
  }']]
  local _, status = hs.execute(command)
  return status
end

--- hs.razer:enableDefaultButtonLayout() -> none
--- Function
--- Remap the buttons on a Razer Tartarus V2 so they trigger their factory default shortcut keys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function razerObject:enableDefaultButtonLayout()
  if not self:productId() == RAZER_TARTARUS_V2_PRODUCT_ID then
    log.ef("Currently only the Razer Tartarus V2 is supported.")
    return
  end

  local command = [[hidutil property --matching '{"ProductID":]] .. string.format("0x%04x", RAZER_TARTARUS_V2_PRODUCT_ID) .. [[}' --set '{"UserKeyMapping":
   [{"HIDKeyboardModifierMappingSrc":0x100000001,
     "HIDKeyboardModifierMappingDst":0x70000001E
   },
   {"HIDKeyboardModifierMappingSrc":0x100000002,
     "HIDKeyboardModifierMappingDst":0x70000001F
   },
   {"HIDKeyboardModifierMappingSrc":0x100000003,
     "HIDKeyboardModifierMappingDst":0x700000020
   },
   {"HIDKeyboardModifierMappingSrc":0x100000004,
     "HIDKeyboardModifierMappingDst":0x700000021
   },
   {"HIDKeyboardModifierMappingSrc":0x100000005,
     "HIDKeyboardModifierMappingDst":0x700000022
   },
   {"HIDKeyboardModifierMappingSrc":0x100000006,
     "HIDKeyboardModifierMappingDst":0x70000002B
   },
   {"HIDKeyboardModifierMappingSrc":0x100000007,
     "HIDKeyboardModifierMappingDst":0x700000014
   },
   {"HIDKeyboardModifierMappingSrc":0x100000008,
     "HIDKeyboardModifierMappingDst":0x70000001A
   },
   {"HIDKeyboardModifierMappingSrc":0x100000009,
     "HIDKeyboardModifierMappingDst":0x700000008
   },
   {"HIDKeyboardModifierMappingSrc":0x100000010,
     "HIDKeyboardModifierMappingDst":0x700000015
   },
   {"HIDKeyboardModifierMappingSrc":0x100000011,
     "HIDKeyboardModifierMappingDst":0x700000039
   },
   {"HIDKeyboardModifierMappingSrc":0x100000012,
     "HIDKeyboardModifierMappingDst":0x700000004
   },
   {"HIDKeyboardModifierMappingSrc":0x100000013,
     "HIDKeyboardModifierMappingDst":0x700000016
   },
   {"HIDKeyboardModifierMappingSrc":0x100000014,
     "HIDKeyboardModifierMappingDst":0x700000007
   },
   {"HIDKeyboardModifierMappingSrc":0x100000015,
     "HIDKeyboardModifierMappingDst":0x700000009
   },
   {"HIDKeyboardModifierMappingSrc":0x100000016,
     "HIDKeyboardModifierMappingDst":0x7000000E1
   },
   {"HIDKeyboardModifierMappingSrc":0x100000017,
     "HIDKeyboardModifierMappingDst":0x70000001D
   },
   {"HIDKeyboardModifierMappingSrc":0x100000018,
     "HIDKeyboardModifierMappingDst":0x70000001B
   },
   {"HIDKeyboardModifierMappingSrc":0x100000019,
     "HIDKeyboardModifierMappingDst":0x700000006
   },
   {"HIDKeyboardModifierMappingSrc":0x100000020,
     "HIDKeyboardModifierMappingDst":0x70000002C
   },
   {"HIDKeyboardModifierMappingSrc":0x100000021,
     "HIDKeyboardModifierMappingDst":0x700000035
   },
   {"HIDKeyboardModifierMappingSrc":0x100000022,
     "HIDKeyboardModifierMappingDst":0x700000052
   },
   {"HIDKeyboardModifierMappingSrc":0x100000023,
     "HIDKeyboardModifierMappingDst":0x700000051
   },
   {"HIDKeyboardModifierMappingSrc":0x100000024,
     "HIDKeyboardModifierMappingDst":0x700000050
   },
   {"HIDKeyboardModifierMappingSrc":0x100000025,
     "HIDKeyboardModifierMappingDst":0x70000004F
   }
   ]
  }']]
  local _, status = hs.execute(command)
  return status
end

return razer
