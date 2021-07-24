--- === hs.razer ===
---
--- Razer device support.
---
--- Special thanks to the [librazermacos](https://github.com/1kc/librazermacos) repo.

local razer = require("hs.razer.internal")

--- hs.razer.remapKeys() -> none
--- Function
--- Remap the buttons on a Razer Tartarus V2 so they don't trigger standard shortcut keys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function razer.remapKeys()

  --[[{
    "0x70000001E", -- [01] 1
    "0x70000001F", -- [02] 2
    "0x700000020", -- [03] 3
    "0x700000021", -- [04] 4
    "0x700000022", -- [05] 5
    "0x70000002B", -- [06] tab
    "0x700000014", -- [07] q
    "0x70000001A", -- [08] w
    "0x700000008", -- [09] e
    "0x700000015", -- [10] r
    "0x700000039", -- [11] caps lock
    "0x700000004", -- [12] a
    "0x700000016", -- [13] s
    "0x700000007", -- [14] d
    "0x700000009", -- [15] f
    "0x7000000E1", -- [16] shift
    "0x70000001D", -- [17] z
    "0x70000001B", -- [18] x
    "0x700000006", -- [19] c
    "0x70000002C", -- [20] spacebar
    "0x700000035", -- [MODE BUTTON] tilda
    "0x700000052", -- [UP] up
    "0x700000051", -- [DOWN] down
    "0x700000050", -- [LEFT] left
    "0x70000004F", -- [RIGHT] right
  }]]

  local command = [[hidutil property --matching '{"ProductID":0x022b}' --set '{"UserKeyMapping":
   [{"HIDKeyboardModifierMappingSrc":0x70000001E,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001F,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000020,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000021,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000022,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000002B,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000014,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001A,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000008,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000015,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000039,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000004,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000016,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000007,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000009,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x7000000E1,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001D,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000001B,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000006,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000002C,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000035,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000052,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000051,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x700000050,
     "HIDKeyboardModifierMappingDst":0x100000000
   },
   {"HIDKeyboardModifierMappingSrc":0x70000004F,
     "HIDKeyboardModifierMappingDst":0x100000000
   }
   ]
  }']]
  hs.execute(command)
end


return razer
