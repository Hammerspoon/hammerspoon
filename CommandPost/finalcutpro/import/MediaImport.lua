local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")
local windowfilter					= require("hs.window.filter")

local WindowWatcher					= require("hs.finalcutpro.ui.WindowWatcher")

local MediaImport = {}

function MediaImport.matches(element)
	if element then
		return element:attributeValue("AXSubrole") == "AXDialog"
		   and element:attributeValue("AXMain")
		   and element:attributeValue("AXModal")
		   and axutils.childWith(element, "AXIdentifier", "_NS:39") ~= nil
	end
	return false
end

function MediaImport:new(app)
	o = {_app = app}
	setmetatable(o, self)
	self.__index = self
	return o
end

function MediaImport:app()
	return self._app
end

function MediaImport:UI()
	return axutils.cache(self, "_ui", function()
		local windowsUI = self:app():windowsUI()
		return windowsUI and self:_findWindowUI(windowsUI)
	end,
	MediaImport.matches)
end

function MediaImport:_findWindowUI(windows)
	for i,window in ipairs(windows) do
		if MediaImport.matches(window) then return window end
	end
	return nil
end

function MediaImport:isShowing()
	return self:UI() ~= nil
end

--- Ensures the MediaImport is showing
function MediaImport:show()
	if not self:isShowing() then
		-- open the window
		if self:app():menuBar():isEnabled("File", "Import", "Media…") then
			self:app():menuBar():selectMenu("File", "Import", "Media…")
			local ui = just.doUntil(function() return self:isShowing() end)
		end
	end
	return self
end

function MediaImport:hide()
	local ui = self:UI()
	if ui then
		local closeBtn = ui:closeButton()
		if closeBtn then
			closeBtn:doPress()
		end
	end
	return self
end

function MediaImport:importAll()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
		end
	end
	return self
end

function MediaImport:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- WATCHERS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

--- Watch for events that happen in the command editor
--- The optional functions will be called when the window
--- is shown or hidden, respectively.
---
--- Parameters:
--- * `events` - A table of functions with to watch. These may be:
--- 	* `show(CommandEditor)` - Triggered when the window is shown.
--- 	* `hide(CommandEditor)` - Triggered when the window is hidden.
---
--- Returns:
--- * An ID which can be passed to `unwatch` to stop watching.
function MediaImport:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end
	
	self._watcher:watch(events)
end

function MediaImport:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return MediaImport