-- Imports
local windowfilter					= require("hs.window.filter")
local axuielement					= require("hs._asm.axuielement")

local log							= require("hs.logger").new("winwatch")

-- The Class
local WindowWatcher = {}


--- hs.finalcutpro.ui.WindowWatcher:new(windowFn) -> WindowWatcher
--- Function:
--- Creates a new WindowWatcher
---
--- Parameters:
---  * `window` 	- the window object (eg. CommandEditor)
---
--- Returns:
---  * `WindowWatcher`	- the new WindowWatcher instance.
function WindowWatcher:new(window)
	o = {_window = window}
	setmetatable(o, self)
	self.__index = self
	return o
end

--- Watch for events that happen in the window
--- The optional functions will be called when the window
--- is shown or hidden, respectively.
---
--- Parameters:
--- * `events` - A table of functions with to watch. These may be:
--- 	* `show(CommandEditor)` - Triggered when the window is shown.
--- 	* `hide(window)` - Triggered when the window is hidden.
---
--- Returns:
--- * An ID which can be passed to `unwatch` to stop watching.
function WindowWatcher:watch(events)
	local startWatching = false
	if not self._watchers then
		self._watchers = {}
		startWatching = true
	end
	self._watchers[#(self._watchers)+1] = {show = events.show, hide = events.hide}
	local id = {id=#(self._watchers)}

	if startWatching then
		--------------------------------------------------------------------------------
		-- Final Cut Pro Window Filter:
		--------------------------------------------------------------------------------
		local bundleID = self._window:app():getBundleID()
		local filter = windowfilter.new(function(window)
			return window:application():bundleID() == bundleID
		end)
		filter.setLogLevel("error") -- The wfilter errors are too annoying.

		--------------------------------------------------------------------------------
		-- Final Cut Pro Window Created:
		--------------------------------------------------------------------------------
		filter:subscribe(
			windowfilter.windowVisible,
			function(window, applicationName)
				local windowUI = axuielement.windowElement(window)
				if self._window:UI() == windowUI and self._window:isShowing() then
					self._windowID = window:id()
					for i,watcher in ipairs(self._watchers) do
						if watcher.show then
							watcher.show(self)
						end
					end
				end
			end,
			true
		)

		--------------------------------------------------------------------------------
		-- Final Cut Pro Window Destroyed:
		--------------------------------------------------------------------------------
		filter:subscribe(
			windowfilter.windowNotVisible,
			function(window, applicationName)
				if window:id() == self._windowID then
					self._windowID = nil

					for i,watcher in ipairs(self._watchers) do
						if watcher.hide then
							watcher.hide(self)
						end
					end
				end
			end,
			true
		)
		self.windowFilter = filter
	end

	return id
end

--- Removes the watch with the specified ID
---
--- Parameters:
--- * `id` - The ID returned from `watch` that wants to be removed.
---
--- Returns:
--- * N/A
function WindowWatcher:unwatch(id)
	local watchers = self._watchers
	if id and id.id and watchers and watchers[id.id] then
		table.remove(watchers, id.id)
	end
end

return WindowWatcher