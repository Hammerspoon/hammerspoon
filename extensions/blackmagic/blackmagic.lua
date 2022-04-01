--- === hs.blackmagic ===
---
--- Support for the Blackmagic DaVinci Resolve Speed Editor Keyboard and Editor Keyboard.
---
--- Example Usage:
--- ```lua
--- blackmagic = nil
---
--- local callback = function(obj, buttonID, pressed, mode, value)
---     if buttonID == "JOG WHEEL" then
---         print("Jog Wheel Mode " .. mode .. ", value: " .. value)
---     else
---         -- If Jog Wheel button pressed, change jog wheel mode
---         -- and activate the LED for that job wheel mode:
---         if buttonID == "SHTL" or buttonID == "JOG" or buttonID == "SCRL" then
---             blackmagic:jogMode(buttonID)
---             blackmagic:led({
---                 ["SHTL"] = buttonID == "SHTL",
---                 ["JOG"] = buttonID == "JOG",
---                 ["SCRL"] = buttonID == "SCRL"
---             })
---             return
---         end
---
---         -- If a normal button is pressed:
---         if pressed then
---             print(buttonID .. " pressed")
---             blackmagic:led({[buttonID] = true})
---         else
---             print(buttonID .. " released")
---             hs.timer.doAfter(5, function()
---                 blackmagic:led({[buttonID] = false})
---             end)
---         end
---     end
--- end
---
--- local discoveryCallback = function(connected, device)
---     if connected then
---         print("New Blackmagic Device Connected!")
---         blackmagic = device
---         blackmagic:led({["SHTL"] = true}) -- Defaults to SHTL jog mode
---         blackmagic:callback(callback)
---     else
---         print("Blackmagic Device Disconnected")
---     end
--- end
---
--- hs.speededitor.init(discoveryCallback)
--- ```
---
--- This extension was thrown together by [Chris Hocking](https://github.com/latenitefilms) for [CommandPost](http://commandpost.io).
---
--- This extension would not be possible without Sylvain Munaut's [genius work](https://github.com/smunaut/blackmagic-misc)
--- figuring out the authentication protocol.
---
--- This extension is based off [Chris Jones'](https://github.com/cmsj) [hs.streamdeck](http://www.hammerspoon.org/docs/hs.streamdeck.html) extension.
---
--- Special thanks to [David Peterson](https://github.com/randomeizer), Morten Bentsen, Håvard Njåstad and Sondre Tungesvik Njåstad.
---
--- This extension uses code based off Sylvain Munaut's [Python Scripts](https://github.com/smunaut/blackmagic-misc) under the following license:
---
--- Copyright 2021 Sylvain Munaut <tnt@246tNt.com>
---
--- Licensed under the Apache License, Version 2.0 (the "License");
--- you may not use this file except in compliance with the License.
--- You may obtain a copy of the License at
---
---     http://www.apache.org/licenses/LICENSE-2.0
---
--- Unless required by applicable law or agreed to in writing, software
--- distributed under the License is distributed on an "AS IS" BASIS,
--- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--- See the License for the specific language governing permissions and
--- limitations under the License.

local module = require("hs.libblackmagic")

--- hs.blackmagic.deviceTypes
--- Constant
--- A table of the supported device types.
module.deviceTypes = {
  "Speed Editor",
  "Editor Keyboard",
}

--- hs.blackmagic.buttonNames
--- Constant
--- A table of the button names used.
module.buttonNames = {
  ["Speed Editor"] = {
      "SMART INSRT",
      "APPND",
      "RIPL OWR",
      "CLOSE UP",
      "PLACE ON TOP",
      "SRC OWR",
      "IN",
      "OUT",
      "TRIM IN",
      "TRIM OUT",
      "ROLL",
      "SLIP SRC",
      "SLIP DEST",
      "TRANS DUR",
      "CUT",
      "DIS",
      "SMTH CUT",
      "SOURCE",
      "TIMELINE",
      "SHTL",
      "JOG",
      "SCRL",
      "ESC",
      "SYNC BIN",
      "AUDIO LEVEL",
      "FULL VIEW",
      "TRANS",
      "SPLIT",
      "SNAP",
      "RIPL DEL",
      "CAM 1",
      "CAM 2",
      "CAM 3",
      "CAM 4",
      "CAM 5",
      "CAM 6",
      "CAM 7",
      "CAM 8",
      "CAM 9",
      "LIVE OWR",
      "VIDEO ONLY",
      "AUDIO ONLY",
      "STOP PLAY",
  },
  ["Editor Keyboard"] = {
      "SMART INSRT",
      "APPND",
      "RIPL OWR",
      "CLOSE UP",
      "PLACE ON TOP",
      "SRC OWR",
      "IN",
      "OUT",
      "TRIM IN",
      "TRIM OUT",
      "ROLL",
      "SLIP SRC",
      "SLIP DEST",
      "TRANS DUR",
      "CUT",
      "DIS",
      "SMTH CUT",
      "TIME CODE",
      "CAM",
      "DATE TIME",
      "CLIP NAME",
      "TRIM EDTOR",
      "F TC",
      "DUR ENTER",
      "00",
      "SOURCE",
      "TIMELINE",
      "SHTL",
      "JOG",
      "SCRL",
      "SYNC BIN",
      "INSRT BLACK",
      "FREEZ",
      "TRANS",
      "PIC IN PIC",
      "SWAP",
      "VIDEO ONLY",
      "AUDIO ONLY",
      "INSERT",
      "O WR",
      "REPL",
      "FIT TO FILL",
      "RIPL DEL",
  }
}

--- hs.blackmagic.ledNames
--- Constant
--- A table of the LED names used by each device type.
module.ledNames = {
  ["Speed Editor"] = {
      "AUDIO ONLY",
      "CAM 1",
      "CAM 2",
      "CAM 3",
      "CAM 4",
      "CAM 5",
      "CAM 6",
      "CAM 7",
      "CAM 8",
      "CAM 9",
      "CLOSE UP",
      "CUT",
      "DIS",
      "JOG",
      "LIVE OWR",
      "SCRL",
      "SHTL",
      "SMTH CUT",
      "SNAP",
      "TRANS",
      "VIDEO ONLY"
  },
  ["Editor Keyboard"] = {
      "SHTL",
      "JOG",
      "SCRL"
  }
}

--- hs.blackmagic.jogModeNames
--- Constant
--- A table of the jog mode names used by each device type.
module.jogModeNames = {
  ["Speed Editor"] = {
      "SHTL",
      "JOG",
      "SCRL"
  },
  ["Editor Keyboard"] = {
      "SHTL",
      "JOG",
      "SCRL"
  },
}

return module
