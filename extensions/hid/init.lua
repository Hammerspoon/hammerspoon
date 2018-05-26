--- === hs.hid ===
---
--- HID interface for Hammerspoon, controls and queries caps lock state
---
--- Portions sourced from (https://discussions.apple.com/thread/7094207).


local module = require("hs.hid.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.capslock = {}

--- hs.hid.capslock.get() -> bool
--- Function
--- Checks the state of the caps lock via HID
---
--- Returns:
---  * true if on, false if off
module.capslock.get = function()
	return module._capslock_query()
end

--- hs.hid.capslock.toggle() -> bool
--- Function
--- Toggles the state of caps lock via HID
---
--- Returns:
---  * true if on, false if off
module.capslock.toggle = function()
	return module._capslock_toggle()
end

--- hs.hid.capslock.set(state) -> bool
--- Function
--- Assigns capslock to the desired state
---
--- Parameters:
---  * state - A boolean indicating desired state
---
--- Returns:
---  * true if on, false if off
module.capslock.set = function(state)
	if state then
		return module._capslock_on()
	else
		return module._capslock_off()
	end
end


module.led = {}

--- hs.hid.led.set(name, state) -> bool
--- Function
--- Assigns HID LED to the desired state
--- Note that this function controls the LED state only,
--- to modify capslock state, use hs.hid.capslock.set
---
--- Parameters:
---  * name  - LED name: "caps", "scroll" or "num"
---  * state - A boolean indicating desired state
---
--- Returns:
---  * true if success, false if error
module.led.set = function(name, state)
    return module._led_set(name, state)
end

-- Return Module Object --------------------------------------------------

return module
