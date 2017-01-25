local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")
local LibrariesList						= require("hs.finalcutpro.main.LibrariesList")
local LibrariesFilmstrip				= require("hs.finalcutpro.main.LibrariesFilmstrip")

local Button							= require("hs.finalcutpro.ui.Button")
local Table								= require("hs.finalcutpro.ui.Table")
local TextField							= require("hs.finalcutpro.ui.TextField")

local Libraries = {}

function Libraries:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Libraries:parent()
	return self._parent
end

function Libraries:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- BROWSER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Libraries:UI()
	if self:isShowing() then
		return axutils.cache(self, "_ui", function()
			return self:parent():UI()
		end)
	end
	return nil
end

function Libraries:isShowing()
	return self:parent():isShowing() and self:parent():showLibraries():isChecked()
end

function Libraries:show()
	local browser = self:parent()
	if browser then
		if not browser:isShowing() then
			browser:showOnPrimary()
		end
		browser:showLibraries():check()
	end
	return self
end

function Libraries:hide()
	self:parent():hide()
	return self
end


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Playheads
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function Libraries:playhead()
	if self:list():isShowing() then
		return self:list():playhead()
	else
		return self:filmstrip():playhead()
	end
end

function Libraries:skimmingPlayhead()
	if self:list():isShowing() then
		return self:list():skimmingPlayhead()
	else
		return self:filmstrip():skimmingPlayhead()
	end
end


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function Libraries:toggleViewMode()
	if not self._viewMode then
		self._viewMode = Button:new(self, function()
			return axutils.childWithID(self:UI(), "_NS:82")
		end)
	end
	return self._viewMode
end

function Libraries:appearanceAndFiltering()
	if not self._appearanceAndFiltering then
		self._appearanceAndFiltering = Button:new(self, function()
			return axutils.childWithID(self:UI(), "_NS:68")
		end)
	end
	return self._appearanceAndFiltering
end

function Libraries:searchToggle()
	if not self._searchToggle then
		self._searchToggle = Button:new(self, function()
			return axutils.childWithID(self:UI(), "_NS:92")
		end)
	end
	return self._searchToggle
end

function Libraries:search()
	if not self._search then
		self._search = TextField:new(self, function()
			return axutils.childWithID(self:mainGroupUI(), "_NS:34")
		end)
	end
	return self._search
end

function Libraries:filterToggle()
	if not self._filterToggle then
		self._filterToggle = Button:new(self, function()
			return axutils.childMatching(self:mainGroupUI(), function(child)
				return child:attributeValue("AXIdentifier") == "_NS:9"
				   and child:attributeValue("AXRole") == "AXButton"
			end)
		end)
	end
	return self._filterToggle
end

Libraries.ALL_CLIPS = 1
Libraries.HIDE_REJECTED = 2
Libraries.NO_RATINGS_OR_KEYWORDS = 3
Libraries.FAVORITES = 4
Libraries.REJECTED = 5
Libraries.UNUSED = 6

function Libraries:selectClipFiltering(filterType)
	local ui = self:UI()
	if ui then
		button = axutils.childWithID(ui, "_NS:9")
		if button then
			local menu = button[1]
			if not menu then
				button:doPress()
				menu = button[1]
			end
			local menuItem = menu[filterType]
			if menuItem then
				menuItem:doPress()
			end
		end
	end
	return self
end

function Libraries:mainGroupUI()
	return axutils.cache(self, "_mainGroup",
	function()
		local ui = self:UI()
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end)
end

function Libraries:filmstrip()
	if not self._filmstrip then
		self._filmstrip = LibrariesFilmstrip:new(self)
	end
	return self._filmstrip
end

function Libraries:list()
	if not self._list then
		self._list = LibrariesList:new(self)
	end
	return self._list
end

function Libraries:sidebar()
	if not self._sidebar then
		self._sidebar = Table:new(self, function()
			return axutils.childMatching(self:mainGroupUI(), Libraries.matchesSidebar)
		end):uncached()
	end
	return self._sidebar
end

function Libraries.matchesSidebar(element)
	return element and element:attributeValue("AXRole") == "AXScrollArea" 
		and element:attributeValue("AXIdentifier") == "_NS:9"
end

function Libraries:isListView()
	return self:list():isShowing()
end

function Libraries:isFilmstripView()
	return self:filmstrip():isShowing()
end

function Libraries:clipsUI()
	if self:isListView() then
		return self:list():clipsUI()
	elseif self:isFilmstripView() then
		return self:filmstrip():clipsUI()
	else
		return nil
	end
end

function Libraries:selectedClipsUI()
	if self:isListView() then
		return self:list():selectedClipsUI()
	elseif self:isFilmstripView() then
		return self:filmstrip():selectedClipsUI()
	else
		return nil
	end
end

function Libraries:showClip(clipUI)
	if self:isListView() then
		self:list():showClip(clipUI)
	else
		self:filmstrip():showClip(clipUI)
	end
	return self
end

function Libraries:selectClip(clipUI)
	if self:isListView() then
		self:list():selectClip(clipUI)
	elseif self:isFilmstripView() then
		self:filmstrip():selectClip(clipUI)
	else
		debugMessage("ERROR: cannot find either list or filmstrip UI")
	end
	return self
end

function Libraries:selectClipAt(index)
	if self:isListView() then
		self:list():selectClipAt(index)
	else
		self:filmstrip():selectClipAt(index)
	end
	return self
end

function Libraries:selectAll(clipsUI)
	if self:isListView() then
		self:list():selectAll(clipsUI)
	else
		self:filmstrip():selectAll(clipsUI)
	end
end

function Libraries:deselectAll()
	if self:isListView() then
		self:list():deselectAll()
	else
		self:filmstrip():deselectAll()
	end
end

function Libraries:isFocused()
	local ui = self:UI()
	return ui and ui:attributeValue("AXFocused") or axutils.childWith(ui, "AXFocused", true) ~= nil
end

function Libraries:saveLayout()
	local layout = {}
	if self:isShowing() then
		layout.showing = true
		layout.sidebar = self:sidebar():saveLayout()
		layout.selectedClips = self:selectedClipsUI()
	end
	return layout
end

function Libraries:loadLayout(layout)
	if layout and layout.showing then
		self:show()
		self:sidebar():loadLayout(layout.sidebar)
		self:selectAll(layout.selectedClips)
	end
end

return Libraries