local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")
local LibrariesBrowser					= require("hs.finalcutpro.main.LibrariesBrowser")
local MediaBrowser						= require("hs.finalcutpro.main.MediaBrowser")
local GeneratorsBrowser					= require("hs.finalcutpro.main.GeneratorsBrowser")

local CheckBox							= require("hs.finalcutpro.ui.CheckBox")

local Browser = {}

function Browser.matches(element)
	local checkBoxes = axutils.childrenWithRole(element, "AXCheckBox")
	return checkBoxes and #checkBoxes == 3
end

function Browser:new(app)
	o = {_app = app}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Browser:app()
	return self._app
end

function Browser:isOnSecondary()
	local ui = self:UI()
	return ui and SecondaryWindow.matches(ui:window())
end

function Browser:isOnPrimary()
	local ui = self:UI()
	return ui and PrimaryWindow.matches(ui:window())
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- BROWSER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Browser:UI()
	return axutils.cache(self, "_ui", function()
		local app = self:app()
		return Browser._findBrowser(app:secondaryWindow(), app:primaryWindow())
	end,
	Browser.matches)
end

function Browser._findBrowser(...)
	for i = 1,select("#", ...) do
		local window = select(i, ...)
		if window then
			local ui = window:browserGroupUI()
			if ui then
				local browser = axutils.childMatching(ui, Browser.matches)
				if browser then return browser end
			end
		end
	end
	return nil
end

function Browser:isShowing()
	return self:UI() ~= nil
end

function Browser:showOnPrimary()
	-- show the parent.
	local menuBar = self:app():menuBar()

	-- if the browser is on the secondary, we need to turn it off before enabling in primary
	menuBar:uncheckMenu("Window", "Show in Secondary Display", "Browser")
	-- Then enable it in the primary
	menuBar:checkMenu("Window", "Show in Workspace", "Browser")
	return self
end

function Browser:showOnSecondary()
	-- show the parent.
	local menuBar = self:app():menuBar()

	menuBar:checkMenu("Window", "Show in Secondary Display", "Browser")
	return self
end


function Browser:hide()
	local menuBar = self:app():menuBar()
	-- Uncheck it from the workspace
	menuBar:uncheckMenu("Window", "Show in Workspace", "Browser")
	return self
end


-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- Sections
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function Browser:showLibraries()
	if not self._showLibraries then
		self._showLibraries = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The library toggle is always the last element.
				return ui[#ui]
			end
			return nil
		end)
	end
	return self._showLibraries
end

function Browser:showMedia()
	if not self._showMedia then
		self._showMedia = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The media toggle is always the second-last element.
				return ui[#ui-1]
			end
			return nil
		end)
	end
	return self._showMedia
end

function Browser:showGenerators()
	if not self._showGenerators then
		self._showGenerators = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The generators toggle is always the third-last element.
				return ui[#ui-2]
			end
			return nil
		end)
	end
	return self._showGenerators
end

function Browser:libraries()
	if not self._libraries then
		self._libraries = LibrariesBrowser:new(self)
	end
	return self._libraries
end

function Browser:media()
	if not self._media then
		self._media = MediaBrowser:new(self)
	end
	return self._media
end

function Browser:generators()
	if not self._generators then
		self._generators = GeneratorsBrowser:new(self)
	end
	return self._generators
end

function Browser:saveLayout()
	local layout = {}
	if self:isShowing() then
		layout.showing = true
		layout.onPrimary = self:isOnPrimary()
		layout.onSecondary = self:isOnSecondary()
		
		layout.showLibraries = self:showLibraries():saveLayout()
		layout.showMedia = self:showMedia():saveLayout()
		layout.showGenerators = self:showGenerators():saveLayout()
		
		layout.libraries = self:libraries():saveLayout()
		layout.media = self:media():saveLayout()
		layout.generators = self:generators():saveLayout()
	end
	return layout
end

function Browser:loadLayout(layout)
	if layout and layout.showing then
		if layout.onPrimary then self:showOnPrimary() end
		if layout.onSecondary then self:showOnSecondary() end
		
		self:generators():loadLayout(layout.generators)
		self:media():loadLayout(layout.media)
		self:libraries():loadLayout(layout.libraries)
		
		self:showGenerators():loadLayout(layout.showGenerators)
		self:showMedia():loadLayout(layout.showMedia)
		self:showLibraries():loadLayout(layout.showLibraries)
	end
end

return Browser