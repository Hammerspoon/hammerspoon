--- === hs.razer ===
---
--- Razer device support.
---
--- This extension supports the following Razer keypad devices:
---
---  * Razer Nostromo
---  * Razer Orbweaver
---  * Razer Orbweaver Chroma
---  * Razer Tartarus
---  * Razer Tartarus Chroma
---  * Razer Tartarus Pro
---  * Razer Tartarus V2
---
--- It allows you to trigger callbacks when you press buttons and use the
--- scroll wheel, as well as allowing you to change the LED backlights
--- on the buttons and scroll wheel, and control the three status lights.
---
--- By default, the Razer keypads triggers regular keyboard commands
--- (i.e. pressing the "01" key will type "1"). However, you can use the
--- `:defaultKeyboardLayout(false)` method to prevent this. This works by
--- remapping the default shortcut keys to "dummy" keys, so that they
--- don't trigger regular keypresses in macOS.
---
--- Like the [`hs.streamdeck`](http://www.hammerspoon.org/docs/hs.streamdeck.html) extension, this extension has been
--- designed to be modular, so it's possible for others to develop support
--- for additional Razer devices later down the line, if there's interest.
---
--- This extension was thrown together by [Chris Hocking](https://github.com/latenitefilms) for [CommandPost](https://commandpost.io).
---
--- This extension is based off the [`hs.streamdeck`](http://www.hammerspoon.org/docs/hs.streamdeck.html) extension by [Chris Jones](https://github.com/cmsj).
---
--- Special thanks to the authors of these awesome documents & resources:
---
---  - [Information on USB Packets](https://www.beyondlogic.org/usbnutshell/usb6.shtml)
---  - [AppleUSBDefinitions.h](https://lab.qaq.wiki/Lakr233/IOKit-deploy/-/blob/master/IOKit/usb/AppleUSBDefinitions.h)
---  - [hidutil key remapping generator for macOS](https://hidutil-generator.netlify.app)
---  - [macOS function key remapping with hidutil](https://www.nanoant.com/mac/macos-function-key-remapping-with-hidutil)
---  - [HID Device Property Keys](https://developer.apple.com/documentation/iokit/iohidkeys_h_user-space/hid_device_property_keys)

local timer         = require("hs.timer")
local color         = require("hs.drawing.color")
local console       = require("hs.console")

local razer         = require("hs.librazer")

local log           = require("hs.logger").new("razer")

local razerObject   = hs.getObjectMetatable("hs.razer")
local execute       = hs.execute

--- hs.razer:defaultKeyboardLayout(enabled) -> boolean
--- Method
--- Allows you to remap the default Keyboard Layout on a Razer device so that the buttons no longer trigger their factory default actions, or restore the default keyboard layout.
---
--- Parameters:
---  * enabled - If `true` the Razer default will use its default keyboard layout.
---
--- Returns:
---  * The `hs.razer` object.
---  * `true` if successful otherwise `false`
function razerObject:defaultKeyboardLayout(enabled)
  local productID = "0x" .. string.upper(string.format("%04x", self:_productID()))
  local remapping = self:_remapping()

  if not remapping then
    log.ef("This Razer device does not support remapping.")
    return false
  end

  local command = [[hidutil property --matching '{"ProductID":]] .. productID .. [[}' --set '{"UserKeyMapping":[]] .. "\n"
  for realID, dummyID in pairs(remapping) do
    local src = enabled and realID or dummyID
    local dst = enabled and dummyID or realID
    command = command .. [[   {"HIDKeyboardModifierMappingSrc":]] .. src .. [[,]] .. "\n"
    command = command .. [[     "HIDKeyboardModifierMappingDst":]] .. dst .. "\n"
    command = command .. [[   },]] .. "\n"
  end
  command = command:sub(1, #command - 1)
  command = command .. " ]" .. "\n"
  command = command .. "}'"

  local _, status = execute(command)
  return self, status == true
end

--- hs.razer.unitTests() -> none
--- Function
--- Runs some basic unit tests when a Razer Tartarus V2 is connected.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Because `hs.razer` relies on a physical device to
---    be connected for testing, this method exists so that
---    Hammerspoon developers can test the extension outside
---    of the usual GitHub tests. It can also be used for
---    user troubleshooting.
---  * This feature currently only works on the Razer Tartarus V2.
function razer.unitTests()

  console.clearConsole()

  razer._unitTestDevice    = nil
  razer._unitTestInterval  = 10
  razer._unitTestOffset    = 1

  local result
  local doAfter = timer.doAfter

  hs.razer.init(function(connected)

    if not connected then
      log.ef("No Razer device connected. Unit test failed.")
      return
    end

    local d = hs.razer.getDevice(1)

    if not d then
      log.ef("Failed to get Razer Device. Unit test failed.")
      return
    end

    if not d.productID == 0x022b then
      log.ef("This unit test currently only works on the Razer Tartarus V2.")
      return
    end

    razer._unitTestDevice = d

    print(string.format(" - Device Connected: %s", razer._unitTestDevice:name()))

    -- ===========================================================================
    -- Brightness 100%:
    -- ===========================================================================
    _, result = razer._unitTestDevice:brightness(100)
    if result then
      print(" - [PASSED] Brightness 100%")
    else
      print(" - [FAILED] Brightness 100%")
    end

    -- ===========================================================================
    -- Turn backlights off:
    -- ===========================================================================
    _, result = razer._unitTestDevice:backlightsOff()
    if result then
      print(" - [PASSED] Turning Off Backlights")
    else
      print(" - [FAILED] Turning Off Backlights")
    end

    -- ===========================================================================
    -- Orange Status Light Off:
    -- ===========================================================================
    _, result = razer._unitTestDevice:orangeStatusLight(false)
    if result == false then
      print(" - [PASSED] Orange Status Light Off")
    else
      print(" - [FAILED] Orange Status Light Off")
    end

    -- ===========================================================================
    -- Green Status Light Off:
    -- ===========================================================================
    _, result = razer._unitTestDevice:greenStatusLight(false)
    if result == false then
      print(" - [PASSED] Green Status Light Off")
    else
      print(" - [FAILED] Green Status Light Off")
    end

    -- ===========================================================================
    -- Blue Status Light Off:
    -- ===========================================================================
    _, result = razer._unitTestDevice:blueStatusLight(false)
    if result == false then
      print(" - [PASSED] Blue Status Light Off")
    else
      print(" - [FAILED] Blue Status Light Off")
    end

    -- ===========================================================================
    -- Setup callback:
    -- ===========================================================================
    razer._unitTestDevice:callback(function(_, buttonName, buttonAction)
        print(string.format("   - (%s - %s)", buttonName, buttonAction))
    end)
    print(" - [PASSED] Button Callback Enabled - press some buttons and scroll wheel to test")

    -- ===========================================================================
    -- Disable default keyboard layout:
    -- ===========================================================================
    _, result = razer._unitTestDevice:defaultKeyboardLayout(false)
    if result then
      print(" - [PASSED] Disabling Default Button Layout")
    else
      print(" - [FAILED] Disabling Default Button Layout")
    end

    -- ===========================================================================
    -- Enable default keyboard layout:
    -- ===========================================================================
    _, result = razer._unitTestDevice:defaultKeyboardLayout(true)
    if result then
      print(" - [PASSED] Enabling Default Button Layout")
    else
      print(" - [FAILED] Enabling Default Button Layout")
    end

    -- ===========================================================================
    -- Disable default keyboard layout:
    -- ===========================================================================
    _, result = razer._unitTestDevice:defaultKeyboardLayout(false)
    if result then
      print(" - [PASSED] Disabling Default Button Layout")
    else
      print(" - [FAILED] Disabling Default Button Layout")
    end

    -- ===========================================================================
    -- Status Lights:
    -- ===========================================================================

      -- ===========================================================================
      -- Orange Status Light On:
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        print(" - Testing Status Lights:")

        _, result = razer._unitTestDevice:orangeStatusLight(true)
        if result then
          print("  - [PASSED] Orange Status Light On")
        else
          print("  - [FAILED] Orange Status Light On")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Green Status Light On:
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:greenStatusLight(true)
        if result then
          print("  - [PASSED] Green Status Light On")
        else
          print("  - [FAILED] Green Status Light On")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Blue Status Light On:
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:blueStatusLight(true)
        if result then
          print("  - [PASSED] Blue Status Light On")
        else
          print("  - [FAILED] Blue Status Light On")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

  -- ===========================================================================
  -- Testing Backlights:
  -- ===========================================================================

      -- ===========================================================================
      -- Wave (Left, Fast):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        print(" - Testing Backlights:")

        _, result = razer._unitTestDevice:backlightsWave(10, "left")
        if result then
          print("  - [PASSED] Wave (Left, Fast)")
        else
          print("  - [FAILED] Wave (Left, Fast)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Wave (Right, Fast):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsWave(10, "right")
        if result then
          print("  - [PASSED] Wave (Right, Fast)")
        else
          print("  - [FAILED] Wave (Right, Fast)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Wave (Left, Slow):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsWave(200, "left")
        if result then
          print("  - [PASSED] Wave (Left, Slow)")
        else
          print("  - [FAILED] Wave (Left, Slow)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Wave (Right, Slow):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsWave(200, "right")
        if result then
          print("  - [PASSED] Wave (Right, Slow)")
        else
          print("  - [FAILED] Wave (Right, Slow)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Spectrum:
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsSpectrum()
        if result then
          print("  - [PASSED] Spectrum")
        else
          print("  - [FAILED] Spectrum")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Reactive (Red, Speed 1):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsReactive(1, color.red)
        if result then
          print("  - [PASSED] Reactive (Red, Speed 1) - press some buttons and scroll wheel to test")
        else
          print("  - [FAILED] Reactive (Red, Speed 1) - press some buttons and scroll wheel to test")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Reactive (Red, Speed 2):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsReactive(2, color.red)
        if result then
          print("  - [PASSED] Reactive (Red, Speed 2) - press some buttons and scroll wheel to test")
        else
          print("  - [FAILED] Reactive (Red, Speed 2) - press some buttons and scroll wheel to test")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Reactive (Red, Speed 3):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsReactive(3, color.red)
        if result then
          print("  - [PASSED] Reactive (Red, Speed 3) - press some buttons and scroll wheel to test")
        else
          print("  - [FAILED] Reactive (Red, Speed 3) - press some buttons and scroll wheel to test")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Reactive (Red, Speed 4):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsReactive(4, color.red)
        if result then
          print("  - [PASSED] Reactive (Red, Speed 4) - press some buttons and scroll wheel to test")
        else
          print("  - [FAILED] Reactive (Red, Speed 4) - press some buttons and scroll wheel to test")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Static (Blue):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsStatic(color.blue)
        if result then
          print("  - [PASSED] Static (Blue)")
        else
          print("  - [FAILED] Static (Blue)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Starlight (Red, Fast):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsStarlight(1, color.red)
        if result then
          print("  - [PASSED] Starlight (Red, Fast)")
        else
          print("  - [FAILED] Starlight (Red, Fast)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Starlight (Red + Blue, Fast):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsStarlight(1, color.red, color.blue)
        if result then
          print("  - [PASSED] Starlight (Red + Blue, Fast)")
        else
          print("  - [FAILED] Starlight (Red + Blue, Fast)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Starlight (Random, Fast):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsStarlight(1)
        if result then
          print("  - [PASSED] Starlight (Random, Fast)")
        else
          print("  - [FAILED] Starlight (Random, Fast)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Breathing (Red):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsBreathing(color.red)
        if result then
          print("  - [PASSED] Breathing (Red)")
        else
          print("  - [FAILED] Breathing (Red)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Breathing (Red + Blue):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsBreathing(color.red, color.blue)
        if result then
          print("  - [PASSED] Breathing (Red + Blue)")
        else
          print("  - [FAILED] Breathing (Red + Blue)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Breathing (Random):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsBreathing()
        if result then
          print("  - [PASSED] Breathing (Random)")
        else
          print("  - [FAILED] Breathing (Random)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Custom (Red, Green, Blue):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsCustom({color.red, color.green, color.blue})
        if result then
          print("  - [PASSED] Custom (Red, Green, Blue)")
        else
          print("  - [FAILED] Custom (Red, Green, Blue)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Custom (Red, Black, Red):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsCustom({color.red, nil, color.red})
        if result then
          print("  - [PASSED] Custom (Red, Off, Red)")
        else
          print("  - [FAILED] Custom (Red, Off, Red)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Custom (All Green):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsCustom({
          color.green, color.green, color.green, color.green, color.green, nil,
          color.green, color.green, color.green, color.green, color.green, nil,
          color.green, color.green, color.green, color.green, color.green, nil,
          color.green, color.green, color.green, color.green, color.green, color.green
        })
        if result then
          print("  - [PASSED] Custom (All Green)")
        else
          print("  - [FAILED] Custom (All Green)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

      -- ===========================================================================
      -- Custom (All White):
      -- ===========================================================================
      doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
        _, result = razer._unitTestDevice:backlightsCustom({
          color.white, color.white, color.white, color.white, color.white, nil,
          color.white, color.white, color.white, color.white, color.white, nil,
          color.white, color.white, color.white, color.white, color.white, nil,
          color.white, color.white, color.white, color.white, color.white, color.white
        })
        if result then
          print("  - [PASSED] Custom (All White)")
        else
          print("  - [FAILED] Custom (All White)")
        end
      end)
      razer._unitTestOffset = razer._unitTestOffset + 1

  -- ===========================================================================
  -- Testing Brightness:
  -- ===========================================================================

    -- ===========================================================================
    -- Brightness 100%:
    -- ===========================================================================
    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      print(" - Testing Brightness:")

      _, result = razer._unitTestDevice:brightness(100)
      if result then
        print("  - [PASSED] Brightness 100%")
      else
        print("  - [FAILED] Brightness 100%")
      end
    end)
    razer._unitTestOffset = razer._unitTestOffset + 1

    -- ===========================================================================
    -- Brightness 50%:
    -- ===========================================================================
    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      _, result = razer._unitTestDevice:brightness(50)
      if result then
        print("  - [PASSED] Brightness 50%")
      else
        print("  - [FAILED] Brightness 50%")
      end
    end)
    razer._unitTestOffset = razer._unitTestOffset + 1

    -- ===========================================================================
    -- Brightness 0%:
    -- ===========================================================================
    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      _, result = razer._unitTestDevice:brightness(0)
      if result then
        print("  - [PASSED] Brightness 0%")
      else
        print("  - [FAILED] Brightness 0%")
      end
    end)
    razer._unitTestOffset = razer._unitTestOffset + 1

    -- ===========================================================================
    -- Brightness 100%:
    -- ===========================================================================
    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      _, result = razer._unitTestDevice:brightness(100)
      if result then
        print("  - [PASSED] Brightness 100%")
      else
        print("  - [FAILED] Brightness 100%")
      end
    end)
    razer._unitTestOffset = razer._unitTestOffset + 1

    -- ===========================================================================
    -- Backlights Off:
    -- ===========================================================================
    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      _, result = razer._unitTestDevice:backlightsOff()
      if result then
        print("  - [PASSED] Backlights Off")
      else
        print("  - [FAILED] Backlights Off")
      end
    end)
    razer._unitTestOffset = razer._unitTestOffset + 1

    doAfter(razer._unitTestInterval * razer._unitTestOffset, function()
      -- ===========================================================================
      -- Enable default keyboard layout:
      -- ===========================================================================
      _, result = razer._unitTestDevice:defaultKeyboardLayout(true)
      if result then
        print(" - [PASSED] Enabling Default Button Layout")
      else
        print(" - [FAILED] Enabling Default Button Layout")
      end

      -- ===========================================================================
      -- Test Garbage Collection:
      -- ===========================================================================
      print(" - Testing Garbage Collection")
      razer._unitTestDevice    = nil
      razer._unitTestInterval  = nil
      razer._unitTestOffset    = nil
      collectgarbage()
      collectgarbage()
      print("- Unit Tests Finished")
    end)

  end)

end

return razer
