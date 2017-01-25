local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")
local Button							= require("hs.finalcutpro.ui.Button")
local Table								= require("hs.finalcutpro.ui.Table")
local ScrollArea						= require("hs.finalcutpro.ui.ScrollArea")
local CheckBox							= require("hs.finalcutpro.ui.CheckBox")
local PopUpButton						= require("hs.finalcutpro.ui.PopUpButton")
local TextField							= require("hs.finalcutpro.ui.TextField")

local MediaBrowser = {}

MediaBrowser.TITLE = "Photos and Audio"

MediaBrowser.MAX_SECTIONS = 4
MediaBrowser.PHOTOS = 1
MediaBrowser.GARAGE_BAND = 2
MediaBrowser.ITUNES = 3
MediaBrowser.SOUND_EFFECTS = 4

function MediaBrowser:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function MediaBrowser:parent()
	return self._parent
end

function MediaBrowser:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- MediaBrowser UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function MediaBrowser:UI()
	if self:isShowing() then
		return axutils.cache(self, "_ui", function()
			return self:parent():UI()
		end)
	end
	return nil
end

function MediaBrowser:isShowing()
	return self:parent():showMedia():isChecked()
end

function MediaBrowser:show()
	local menuBar = self:app():menuBar()
	-- Go there direct
	menuBar:selectMenu("Window", "Go To", MediaBrowser.TITLE)
	just.doUntil(function() return self:isShowing() end)
	return self
end

function MediaBrowser:hide()
	self:parent():hide()
	return self
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Sections
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function MediaBrowser:mainGroupUI()
	return axutils.cache(self, "_mainGroup",
	function()
		local ui = self:UI()
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end)
end

function MediaBrowser:sidebar()
	if not self._sidebar then
		self._sidebar = Table:new(self, function()
			return axutils.childWithID(self:mainGroupUI(), "_NS:9")
		end)
	end
	return self._sidebar
end

function MediaBrowser:group()
	if not self._group then
		self._group = PopUpButton:new(self, function()
			return axutils.childWithRole(self:UI(), "AXPopUpButton")
		end)
	end
	return self._group
end

function MediaBrowser:search()
	if not self._search then
		self._search = TextField:new(self, function()
			return axutils.childWithRole(self:mainGroupUI(), "AXTextField")
		end)
	end
	return self._search
end

function MediaBrowser:showSidebar()
	self:app():menuBar():checkMenu("Window", "Show in Workspace", "Sidebar")
end

function MediaBrowser:topCategoriesUI()
	return self:sidebar():rowsUI(function(row)
		return row:attributeValue("AXDisclosureLevel") == 0
	end)
end

function MediaBrowser:showSection(index)
	self:showSidebar()
	local topCategories = self:topCategoriesUI()
	if topCategories and #topCategories == MediaBrowser.MAX_SECTIONS then
		self:sidebar():selectRow(topCategories[index])
	end
	return self
end

function MediaBrowser:showPhotos()
	return self:showSection(MediaBrowser.PHOTOS)
end

function MediaBrowser:showGarageBand()
	return self:showSection(MediaBrowser.GARAGE_BAND)
end

function MediaBrowser:showITunes()
	return self:showSection(MediaBrowser.ITUNES)
end

function MediaBrowser:showSoundEffects()
	return self:showSection(MediaBrowser.SOUND_EFFECTS)
end

function MediaBrowser:saveLayout()
	local layout = {}
	if self:isShowing() then
		layout.showing = true
		layout.sidebar = self:sidebar():saveLayout()
		layout.search = self:search():saveLayout()
	end
	return layout
end

function MediaBrowser:loadLayout(layout)
	if layout and layout.showing then
		self:show()
		self:sidebar():loadLayout(layout.sidebar)
		self:search():loadLayout(layout.sidebar)
	end
end

return MediaBrowser