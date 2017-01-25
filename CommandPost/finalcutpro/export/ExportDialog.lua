local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")

local SaveSheet						= require("hs.finalcutpro.export.SaveSheet")
local WindowWatcher					= require("hs.finalcutpro.ui.WindowWatcher")

local ExportDialog = {}

function ExportDialog.matches(element)
	if element then
		return element:attributeValue("AXSubrole") == "AXDialog"
		   and element:attributeValue("AXModal")
		   and axutils.childWithID(element, "_NS:17") ~= nil
	end
	return false
end

function ExportDialog:new(app)
	o = {_app = app}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ExportDialog:app()
	return self._app
end

function ExportDialog:UI()
	return axutils.cache(self, "_ui", function()
		local windowsUI = self:app():windowsUI()
		return windowsUI and self:_findWindowUI(windowsUI)
	end,
	ExportDialog.matches)
end

function ExportDialog:_findWindowUI(windows)
	for i,window in ipairs(windows) do
		if ExportDialog.matches(window) then return window end
	end
	return nil
end

function ExportDialog:isShowing()
	return self:UI() ~= nil
end

--- Ensures the ExportDialog is showing
function ExportDialog:show()
	if not self:isShowing() then
		-- open the window
		if self:app():menuBar():isEnabled("Final Cut Pro", "Commands", "Customize…") then
			self:app():menuBar():selectMenu("Final Cut Pro", "Commands", "Customize…")
			local ui = just.doUntil(function() return self:UI() end)
		end
	end
	return self
end

function ExportDialog:hide()
	self:pressCancel()
end

function ExportDialog:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
		end
	end
	return self
end

function ExportDialog:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

function ExportDialog:pressNext()
	local ui = self:UI()
	if ui then
		local nextBtn = ui:defaultButton()
		if nextBtn then
			nextBtn:doPress()
		end
	end
	return self
end

function ExportDialog:saveSheet()
	if not self._saveSheet then
		self._saveSheet = SaveSheet:new(self)
	end
	return self._saveSheet
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
function ExportDialog:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end
	
	self._watcher:watch(events)
end

function ExportDialog:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return ExportDialog