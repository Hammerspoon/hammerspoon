local keycodes								= require("hs.keycodes")

local mod = {}

mod.englishKeyCodes = {
	["'"] = 39,
	[","] = 43,
	["-"] = 27,
	["."] = 47,
	["/"] = 44,
	["0"] = 29,
	["1"] = 18,
	["2"] = 19,
	["3"] = 20,
	["4"] = 21,
	["5"] = 23,
	["6"] = 22,
	["7"] = 26,
	["8"] = 28,
	["9"] = 25,
	[";"] = 41,
	["="] = 24,
	["["] = 33,
	["\\"] = 42,
	["]"] = 30,
	["`"] = 50,
	["a"] = 0,
	["b"] = 11,
	["c"] = 8,
	["d"] = 2,
	["delete"] = 51,
	["down"] = 125,
	["e"] = 14,
	["end"] = 119,
	["escape"] = 53,
	["f"] = 3,
	["f1"] = 122,
	["f10"] = 109,
	["f11"] = 103,
	["f12"] = 111,
	["f13"] = 105,
	["f14"] = 107,
	["f15"] = 113,
	["f16"] = 106,
	["f17"] = 64,
	["f18"] = 79,
	["f19"] = 80,
	["f2"] = 120,
	["f20"] = 90,
	["f3"] = 99,
	["f4"] = 118,
	["f5"] = 96,
	["f6"] = 97,
	["f7"] = 98,
	["f8"] = 100,
	["f9"] = 101,
	["forwarddelete"] = 117,
	["g"] = 5,
	["h"] = 4,
	["help"] = 114,
	["home"] = 115,
	["i"] = 34,
	["j"] = 38,
	["k"] = 40,
	["l"] = 37,
	["left"] = 123,
	["m"] = 46,
	["n"] = 45,
	["o"] = 31,
	["p"] = 35,
	["pad*"] = 67,
	["pad+"] = 69,
	["pad-"] = 78,
	["pad."] = 65,
	["pad/"] = 75,
	["pad0"] = 82,
	["pad1"] = 83,
	["pad2"] = 84,
	["pad3"] = 85,
	["pad4"] = 86,
	["pad5"] = 87,
	["pad6"] = 88,
	["pad7"] = 89,
	["pad8"] = 91,
	["pad9"] = 92,
	["pad="] = 81,
	["padclear"] = 71,
	["padenter"] = 76,
	["pagedown"] = 121,
	["pageup"] = 116,
	["q"] = 12,
	["r"] = 15,
	["return"] = 36,
	["right"] = 124,
	["s"] = 1,
	["space"] = 49,
	["t"] = 17,
	["tab"] = 48,
	["u"] = 32,
	["up"] = 126,
	["v"] = 9,
	["w"] = 13,
	["x"] = 7,
	["y"] = 16,
	["z"] = 6,
	["§"] = 10
}

--- keyCodeTranslator() -> string
--- Function
--- Translates string into Keycode
---
--- Parameters:
---  * input - string
---
--- Returns:
---  * Keycode as String or ""
---
function mod.keyCodeTranslator(input)
	local result = mod.englishKeyCodes[input]
	if not result then
		result = keycodes.map[input]
		if not result then
			result = ""
		end
	end
	return result
end


--- hs.finalcutpro.translateKeyboardCharacters() -> string
--- Function
--- Translate Keyboard Character Strings from Command Set Format into Hammerspoon Format.
---
--- Parameters:
---  * input - Character String
---
--- Returns:
---  * Keycode as String or ""
---
function mod.translateKeyboardCharacters(input)

	local result = tostring(input)

	if input == " " 									then result = "space"		end
	if string.find(input, "NSF1FunctionKey") 			then result = "f1" 			end
	if string.find(input, "NSF2FunctionKey") 			then result = "f2" 			end
	if string.find(input, "NSF3FunctionKey") 			then result = "f3" 			end
	if string.find(input, "NSF4FunctionKey") 			then result = "f4" 			end
	if string.find(input, "NSF5FunctionKey") 			then result = "f5" 			end
	if string.find(input, "NSF6FunctionKey") 			then result = "f6" 			end
	if string.find(input, "NSF7FunctionKey") 			then result = "f7" 			end
	if string.find(input, "NSF8FunctionKey") 			then result = "f8" 			end
	if string.find(input, "NSF9FunctionKey") 			then result = "f9" 			end
	if string.find(input, "NSF10FunctionKey") 			then result = "f10" 		end
	if string.find(input, "NSF11FunctionKey") 			then result = "f11" 		end
	if string.find(input, "NSF12FunctionKey") 			then result = "f12" 		end
	if string.find(input, "NSF13FunctionKey") 			then result = "f13" 		end
	if string.find(input, "NSF14FunctionKey") 			then result = "f14" 		end
	if string.find(input, "NSF15FunctionKey") 			then result = "f15" 		end
	if string.find(input, "NSF16FunctionKey") 			then result = "f16" 		end
	if string.find(input, "NSF17FunctionKey") 			then result = "f17" 		end
	if string.find(input, "NSF18FunctionKey") 			then result = "f18" 		end
	if string.find(input, "NSF19FunctionKey") 			then result = "f19" 		end
	if string.find(input, "NSF20FunctionKey") 			then result = "f20" 		end
	if string.find(input, "NSUpArrowFunctionKey") 		then result = "up" 			end
	if string.find(input, "NSDownArrowFunctionKey") 	then result = "down" 		end
	if string.find(input, "NSLeftArrowFunctionKey") 	then result = "left" 		end
	if string.find(input, "NSRightArrowFunctionKey") 	then result = "right" 		end
	if string.find(input, "NSDeleteFunctionKey") 		then result = "delete" 		end
	if string.find(input, "NSHomeFunctionKey") 			then result = "home" 		end
	if string.find(input, "NSEndFunctionKey") 			then result = "end" 		end
	if string.find(input, "NSPageUpFunctionKey") 		then result = "pageup" 		end
	if string.find(input, "NSPageDownFunctionKey") 		then result = "pagedown" 	end

	--------------------------------------------------------------------------------
	-- Convert to lowercase:
	--------------------------------------------------------------------------------
	result = string.lower(result)

	local convertedToKeycode = mod.keyCodeTranslator(result)
	if convertedToKeycode == nil then
		writeToConsole("NON-FATAL ERROR: Failed to translate keyboard character (" .. tostring(input) .. ").")
		result = ""
	else
		result = convertedToKeycode
	end

	return result

end

mod.padKeys = { "*", "+", "/", "-", "=", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "enter" }

--- hs.finalcutpro.translateKeyboardKeypadCharacters() -> string
--- Function
--- Translate Keyboard Keypad Character Strings from Command Set Format into Hammerspoon Format.
---
--- Parameters:
---  * input - Character String
---
--- Returns:
---  * string or nil
---
function mod.translateKeyboardKeypadCharacters(input)

	local result = nil
	for i=1, #padKeys do
		if input == padKeys[i] then result = "pad" .. input end
	end

	return mod.translateKeyboardCharacters(result)

end

--- hs.finalcutpro.translateKeyboardModifiers() -> table
--- Function
--- Translate Keyboard Modifiers from Command Set Format into Hammerspoon Format
---
--- Parameters:
---  * input - Modifiers String
---
--- Returns:
---  * table
---
function mod.translateKeyboardModifiers(input)

	local result = {}
	if string.find(input, "command") then result[#result + 1] = "command" end
	if string.find(input, "control") then result[#result + 1] = "control" end
	if string.find(input, "option") then result[#result + 1] = "option" end
	if string.find(input, "shift") then result[#result + 1] = "shift" end
	return result

end

--- hs.finalcutpro.translateModifierMask() -> table
--- Function
--- Translate Keyboard Modifiers from Command Set Format into Hammerspoon Format
---
--- Parameters:
---  * value - Modifiers String
---
--- Returns:
---  * table
---
function mod.translateModifierMask(value)

	local modifiers = {
		--AlphaShift = 1 << 16,
		shift      = 1 << 17,
		control    = 1 << 18,
		option	   = 1 << 19,
		command    = 1 << 20,
		--NumericPad = 1 << 21,
		--Help       = 1 << 22,
		--Function   = 1 << 23,
	}

	local answer = {}

	for k, v in pairs(modifiers) do
		if (value & v) == v then
			table.insert(answer, k)
		end
	end

	return answer

end

return mod