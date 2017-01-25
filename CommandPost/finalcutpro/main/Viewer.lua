local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")

local Viewer = {}


function Viewer.matches(element)
	-- Viewers have a single 'AXContents' element
	local contents = element:attributeValue("AXContents")
	return contents and #contents == 1 
	   and contents[1]:attributeValue("AXRole") == "AXSplitGroup"
	   and #(contents[1]) > 0
end

function Viewer:new(app, eventViewer)
	o = {
		_app = app, 
		_eventViewer = eventViewer
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Viewer:app()
	return self._app
end

function Viewer:isEventViewer()
	return self._eventViewer
end

function Viewer:isMainViewer()
	return not self._eventViewer
end

function Viewer:isOnSecondary()
	local ui = self:UI()
	return ui and SecondaryWindow.matches(ui:window())
end

function Viewer:isOnPrimary()
	local ui = self:UI()
	return ui and PrimaryWindow.matches(ui:window())
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- BROWSER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Viewer:UI()
	return axutils.cache(self, "_ui", function()
		local app = self:app()
		if self:isMainViewer() then
			return self:findViewerUI(app:secondaryWindow(), app:primaryWindow())
		else
			return self:findEventViewerUI(app:secondaryWindow(), app:primaryWindow())
		end
	end,
	Viewer.matches)
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- VIEWER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Viewer:findViewerUI(...)
	for i = 1,select("#", ...) do
		local window = select(i, ...)
		if window then
			local top = window:viewerGroupUI()
			local ui = nil
			if top then
				for i,child in ipairs(top) do
					-- There can be two viwers enabled
					if Viewer.matches(child) then
						-- Both the event viewer and standard viewer have the ID, so pick the right-most one
						if ui == nil or ui:position().x < child:position().x then
							ui = child
						end
					end
				end
			end
			if ui then return ui end
		end
	end
	return nil
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- EVENT VIEWER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Viewer:findEventViewerUI(...)
	for i = 1,select("#", ...) do
		local window = select(i, ...)
		if window then
			local top = window:viewerGroupUI()
			local ui = nil
			local viewerCount = 0
			if top then
				for i,child in ipairs(top) do
					-- There can be two viwers enabled
					if Viewer.matches(child) then
						viewerCount = viewerCount + 1
						-- Both the event viewer and standard viewer have the ID, so pick the left-most one
						if ui == nil or ui:position().x > child:position().x then
							ui = child
						end
					end
				end
			end
			-- Can only be the event viewer if there are two viewers.
			if viewerCount == 2 then
				return ui
			end
		end
	end
	return nil
end


function Viewer:isShowing()
	return self:UI() ~= nil
end

function Viewer:showOnPrimary()
	local menuBar = self:app():menuBar()
	
	-- if the browser is on the secondary, we need to turn it off before enabling in primary
	menuBar:uncheckMenu("Window", "Show in Secondary Display", "Viewers")
	
	if self:isEventViewer() then
		-- Enable the Event Viewer
		menuBar:checkMenu("Window", "Show in Workspace", "Event Viewer")
	end
	
	return self
end

function Viewer:showOnSecondary()
	local menuBar = self:app():menuBar()
	
	menuBar:checkMenu("Window", "Show in Secondary Display", "Viewers")
	
	if self:isEventViewer() then
		-- Enable the Event Viewer
		menuBar:checkMenu("Window", "Show in Workspace", "Event Viewer")
	end
	
	return self
end


function Viewer:hide()
	local menuBar = self:app():menuBar()
	
	if self:isEventViewer() then
		-- Uncheck it from the primary workspace
		menuBar:uncheckMenu("Window", "Show in Workspace", "Event Viewer")
	elseif self:isOnSecondary() then
		-- The Viewer can only be hidden from the Secondary Display
		menuBar:uncheckMenu("Window", "Show in Secondary Display", "Viewers")
	end
	return self
end

function Viewer:topToolbarUI()
	return axutils.cache(self, "_topToolbar", function()
		local ui = self:UI()
		if ui then
			for i,child in ipairs(ui) do
				if axutils.childWith(child, "AXIdentifier", "_NS:16") then
					return child
				end
			end
		end
		return nil
	end)
end

function Viewer:bottomToolbarUI()
	return axutils.cache(self, "_bottomToolbar", function()
		local ui = self:UI()
		if ui then
			for i,child in ipairs(ui) do
				if axutils.childWith(child, "AXIdentifier", "_NS:31") then
					return child
				end
			end
		end
		return nil
	end)
end

function Viewer:hasPlayerControls()
	return self:bottomToolbarUI() ~= nil
end

function Viewer:formatUI()
	return axutils.cache(self, "_format", function()
		local ui = self:topToolbarUI()
		return ui and axutils.childWith(ui, "AXIdentifier", "_NS:274")
	end)
end

function Viewer:getFormat()
	local format = self:formatUI()
	return format and format:value()
end

function Viewer:getFramerate()
	local format = self:getFormat()
	local framerate = format and string.match(format, ' %d%d%.?%d?%d?[pi]')
	return framerate and tonumber(string.sub(framerate, 1,-2))
end

function Viewer:getTitle()
	local titleText = axutils.childWithID(self:topToolbarUI(), "_NS:16")
	return titleText and titleText:value()
end

return Viewer