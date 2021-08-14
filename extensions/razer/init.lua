--- === hs.razer ===
---
--- Razer device support.
---
--- This module allows you to control the LEDs on 130 Razer peripherals.
---
--- It also allows you to trigger a callback on button presses and scroll wheel movements on certain devices.
--- Currently only the Razer Tartarus V2 is supported, however please [submit an issue](https://github.com/Hammerspoon/hammerspoon/issues) if you're interested in other Razer devices.
---
--- By default, the Razer Tartarus V2 triggers regular keyboard commands (i.e. pressing the "01" key will type "1"). You can use the `keyboardDisableDefaults()` method to prevent this.
---
--- This extension was thrown together by [Chris Hocking](https://github.com/latenitefilms) for [CommandPost](https://commandpost.io).
---
--- This extension uses code from the [librazermacos](https://github.com/1kc/librazermacos) project,
--- which is a C library of [OpenRazer](https://github.com/openrazer/openrazer) drivers ported to macOS.
---
--- You can find the librazermacos license [here](https://github.com/1kc/librazermacos/blob/master/LICENSE).
--- You can find the OpenRazer license [here](https://github.com/openrazer/openrazer/blob/master/LICENSE).
---
--- Example usage with a Razer Tartarus V2:
--- ```lua
--- deviceId = hs.razer.devices()[1].internalDeviceId
--- device = hs.razer.new(deviceId)
--- if device then
---   print(string.format("Device Connected: %s", device:name()))
---   if device:productId() == 0x022b then
---     print("Disabling Default Button Layout...")
---     device:keyboardDisableDefaults()
---   end
---   print("Setting up a callback...")
---   device:callback(function(obj, msg, buttonName, buttonAction)
---     print(string.format("obj: %s, msg: %s, buttonName: %s, buttonAction: %s", obj, msg, buttonName, buttonAction))
---   end)
---   device:keyboardBrightness(100)
---   device:keyboardBacklightsCustom({hs.drawing.color.red})
--- end
--- ```

local timer         = require("hs.timer")
local color         = require("hs.drawing.color")
local razer         = require("hs.razer.internal")
local log           = require("hs.logger").new("razer")
local razerObject   = hs.getObjectMetatable("hs.razer")
local execute       = hs.execute

-- remapKeys(productId, enable) -> boolean
-- Function
-- Remap the buttons on a Razer device.
--
-- Parameters:
--  * productId - The product ID of the Razer device as a string
--  * enable - A boolean to enable or disable the remapping
--
-- Returns:
--  * `true` if successful otherwise `false`
local function remapKeys(productId, enable)
  local deviceDetails = razer.supportedDevices()[productId]
  local remapping = deviceDetails and deviceDetails["remapping"]

  if not remapping then
    log.ef("You are not able to remap the buttons on this particular Razer device.\n\nDevelopers can add support for other Razer devices by modifying the device JSON files included in the hs.razer extension.")
    return
  end

  local command = [[hidutil property --matching '{"ProductID":]] .. productId .. [[}' --set '{"UserKeyMapping":[]] .. "\n"
  for realID, dummyID in pairs(remapping) do
    local src = enable and realID or dummyID
    local dst = enable and dummyID or realID
    command = command .. [[   {"HIDKeyboardModifierMappingSrc":]] .. src .. [[,]] .. "\n"
    command = command .. [[     "HIDKeyboardModifierMappingDst":]] .. dst .. "\n"
    command = command .. [[   },]] .. "\n"
  end
  command = command:sub(1, #command - 1)
  command = command .. " ]" .. "\n"
  command = command .. "}'"

  local _, status = execute(command)
  return status == true
end

--- hs.razer:keyboardDisableDefaults() -> boolean
--- Method
--- Remap the buttons on a Razer device so that they don't trigger their factory default shortcut keys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
---
--- Notes:
---  * This feature currently only works on the Razer Tartarus V2.
function razerObject:keyboardDisableDefaults()
  local productId = "0x" .. string.upper(string.format("%04x", self:productId()))
  return remapKeys(productId, false)
end

--- hs.razer:keyboardEnableDefaults() -> boolean
--- Method
--- Remap the buttons on a Razer device so that they trigger their factory default shortcut keys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
---
--- Notes:
---  * This feature currently only works on the Razer Tartarus V2.
function razerObject:keyboardEnableDefaults()
  local productId = "0x" .. string.upper(string.format("%04x", self:productId()))
  return remapKeys(productId, true)
end

--- hs.razer.demo() -> none
--- Function
--- Runs some basic tests when a Razer Tartarus V2 is connected.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function razer.demo()
  local interval = 5
  local speed = 100

  local doAfter = timer.doAfter

  local devices = hs.razer.devices()
  local internalDeviceId
  for id, v in pairs(devices) do
    if v.productId == 0x022b then
      internalDeviceId = v.internalDeviceId
    end
  end

  if not internalDeviceId then
    log.ef("A Razer Tartarus V2 could not be detected. This function only works when a Razer Tartarus V2 is connected to your Mac.")
    return
  end

  local device = hs.razer.new(internalDeviceId)
  if not device then
    log.ef("Failed to connect to the Razer Tartarus V2. Aborted.")
    return
  end

  print(string.format(" - Device Connected: %s", device:name()))

  print(" - Turning Off Backlights")
  device:keyboardBacklightsOff()

  print(" - Button Callback Enabled")
  device:callback(function(obj, msg, buttonName, buttonAction)
    if msg == "received" then
      print(string.format("   - (%s - %s)", buttonName, buttonAction))
    end
  end)

  print(" - Disabling Default Button Layout")
  device:keyboardDisableDefaults()

  print(" - Enabling Default Button Layout")
  device:keyboardEnableDefaults()

  print(" - Disabling Default Button Layout")
  device:keyboardDisableDefaults()

  print("\n\n - Testing Backlights:")

  doAfter(interval * 1, function()
    print("  - Wave (Left)")
    device:keyboardBacklightsWave(speed, "left")
  end)

  doAfter(interval * 2, function()
    print("  - Wave (Right)")
    device:keyboardBacklightsWave(speed, "right")
  end)

  doAfter(interval * 3, function()
    print("  - Spectrum")
    device:keyboardBacklightsSpectrum()
  end)

  doAfter(interval * 4, function()
    print("  - Reactive (Red)")
    device:keyboardBacklightsReactive(speed, color.red)
  end)

  doAfter(interval * 5, function()
    print("  - Static (Blue)")
    device:keyboardBacklightsStatic(color.blue)
  end)

  doAfter(interval * 6, function()
    print("  - Static No Store (Green)")
    device:keyboardBacklightsStaticNoStore(color.green)
  end)

  doAfter(interval * 7, function()
    print("  - Starlight (Red)")
    device:keyboardBacklightsStarlight(speed, color.red)
  end)

  doAfter(interval * 8, function()
    print("  - Starlight (Red + Blue)")
    device:keyboardBacklightsStarlight(speed, color.red, color.blue)
  end)

  doAfter(interval * 9, function()
    print("  - Starlight (Random)")
    device:keyboardBacklightsStarlight(speed)
  end)

  doAfter(interval * 10, function()
    print("  - Breath")
    device:keyboardBacklightsBreath()
  end)

  doAfter(interval * 11, function()
    print("  - Pulsate")
    device:keyboardBacklightsPulsate()
  end)

  doAfter(interval * 12, function()
    print("  - Custom (Red, Green, Blue)")
    device:keyboardBacklightsCustom({color.red, color.green, color.blue})
  end)

  doAfter(interval * 13, function()
    print("  - Custom (Red, Black, Red)")
    device:keyboardBacklightsCustom({color.red, nil, color.red})
  end)

  doAfter(interval * 14, function()
    print("  - Brightness 100%")
    device:keyboardBacklightsStatic(color.white)
  end)

  doAfter(interval * 15, function()
    print("  - Brightness 50%")
    device:keyboardBacklightsStatic(color.white)
    device:keyboardBrightness(50)
  end)

  doAfter(interval * 16, function()
    print("  - Brightness 0%")
    device:keyboardBacklightsStatic(color.white)
    device:keyboardBrightness(0)
  end)

  doAfter(interval * 17, function()
    print("  - Backlights Off")
    device:keyboardBrightness(100)
    device:keyboardBacklightsOff()
  end)

  doAfter(interval * 18, function()
    print(" - Enabling Default Button Layout")
    device:keyboardEnableDefaults()

    print("\n\n- Testing Garbage Collection")
    device = nil
    collectgarbage()
    collectgarbage()
    print("- Demo complete!")
  end)

end

return razer
