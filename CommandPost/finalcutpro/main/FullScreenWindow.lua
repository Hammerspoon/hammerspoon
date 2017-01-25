local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")

local WindowWatcher					= require("hs.finalcutpro.ui.WindowWatcher")

local FullScreenWindow = {}

function FullScreenWindow.matches(element)
	if element and element:attributeValue("AXSubrole") == "AXUnknown"
	and element:attributeValue("AXTitle") == "" then
		local children = element:attributeValue("AXChildren")
		return children and #children == 1 and children[1]:attributeValue("AXRole") == "AXSplitGroup"
	end
	return false
end

function FullScreenWindow:new(app)
	o = {
		_app = app
	}
	setmetatable(o, self)
	self.__index = self
	
	return o
end

function FullScreenWindow:app()
	return self._app
end

function FullScreenWindow:isShowing()
	return self:UI() ~= nil
end

function FullScreenWindow:show()
	-- Currently a null-op. Determin if there are any scenarios where we need to force this.
	return true
end

function FullScreenWindow:UI()
	return axutils.cache(self, "_ui", function()
		local ui = self:app():UI()
		if ui then
			if FullScreenWindow.matches(ui:mainWindow()) then
				return ui:mainWindow()
			else
				local windowsUI = self:app():windowsUI()
				return windowsUI and self:_findWindowUI(windowsUI)
			end
		end
		return nil
	end,
	FullScreenWindow.matches)
end

function FullScreenWindow:_findWindowUI(windows)
	for i,w in ipairs(windows) do
		if FullScreenWindow.matches(w) then return w end
	end
	return nil
end

function FullScreenWindow:isFullScreen()
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

function FullScreenWindow:setFullScreen(isFullScreen)
	local ui = self:UI()
	if ui then ui:setFullScreen(isFullScreen) end
	return self
end

function FullScreenWindow:toggleFullScreen()
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
function FullScreenWindow:rootGroupUI()
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
function FullScreenWindow:viewerGroupUI()
	local ui = self:rootGroupUI()
	if ui then
		local group = nil
		if #ui == 1 then
			group = ui[1]
		else
			group = axutils.childMatching(ui, function(element) return #element == 2 end)
		end
		if #group == 2 and axutils.childWithRole(group, "AXImage") ~= nil then
			return group
		end
	end
	return nil
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
function FullScreenWindow:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end
	
	self._watcher:watch(events)
end

function FullScreenWindow:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return FullScreenWindow
