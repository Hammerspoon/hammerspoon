local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")

local Button						= require("hs.finalcutpro.ui.Button")
local WindowWatcher					= require("hs.finalcutpro.ui.WindowWatcher")

local SecondaryWindow = {}

function SecondaryWindow.matches(element)
	if element and element:attributeValue("AXSubrole") == "AXUnknown"
	and element:attributeValue("AXTitle") ~= "" then
		local children = element:attributeValue("AXChildren")
		return children and #children == 1 and children[1]:attributeValue("AXRole") == "AXSplitGroup"
	end
	return false
end

function SecondaryWindow:new(app)
	o = {
		_app = app
	}
	setmetatable(o, self)
	self.__index = self
	
	return o
end

function SecondaryWindow:app()
	return self._app
end

function SecondaryWindow:isShowing()
	return self:UI() ~= nil
end

function SecondaryWindow:show()
	-- Currently a null-op. Determin if there are any scenarios where we need to force this.
	return true
end

function SecondaryWindow:UI()
	return axutils.cache(self, "_ui", function()
		local ui = self:app():UI()
		if ui then
			if SecondaryWindow.matches(ui:mainWindow()) then
				return ui:mainWindow()
			else
				local windowsUI = self:app():windowsUI()
				return windowsUI and self:_findWindowUI(windowsUI)
			end
		end
		return nil
	end,
	SecondaryWindow.matches)
end

function SecondaryWindow:_findWindowUI(windows)
	for i,w in ipairs(windows) do
		if SecondaryWindow.matches(w) then return w end
	end
	return nil
end

function SecondaryWindow:isFullScreen()
	local ui = self:rootGroupUI()
	if ui then
		-- In full-screen, it can either be a single group, or a sub-group containing the event viewer.
		local group = nil
		if #ui == 1 then
			group = ui[1]
		else
			group = axutils.childMatching(ui, function(element) return #element == 2 end)
		end
		if #group == 2 then
			local image = axutils.childWithRole(group, "AXImage")
			return image ~= nil
		end
	end
	return false
end

function SecondaryWindow:setFullScreen(isFullScreen)
	local ui = self:UI()
	if ui then ui:setFullScreen(isFullScreen) end
	return self
end

function SecondaryWindow:toggleFullScreen()
	local ui = self:UI()
	if ui then ui:setFullScreen(not self:isFullScreen()) end
	return self
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- UI STRUCTURE
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- The top AXSplitGroup contains the 
function SecondaryWindow:rootGroupUI()
	return axutils.cache(self, "_rootGroup", function()
		local ui = self:UI()
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end)
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- VIEWER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function SecondaryWindow:viewerGroupUI()
	return self:rootGroupUI()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function SecondaryWindow:timelineGroupUI()
	return axutils.cache(self, "_timelineGroup", function()
		-- for some reason, the Timeline is burried under three levels
		local root = self:rootGroupUI()
		if root and root[1] and root[1][1] then
			return root[1][1]
		end
	end)
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- BROWSER
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function SecondaryWindow:browserGroupUI()
	return self:rootGroupUI()
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
function SecondaryWindow:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end
	
	self._watcher:watch(events)
end

function SecondaryWindow:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return SecondaryWindow
