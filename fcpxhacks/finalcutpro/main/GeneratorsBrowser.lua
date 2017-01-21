local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")
local tools								= require("hs.fcpxhacks.modules.tools")
local geometry							= require("hs.geometry")

local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")
local Button							= require("hs.finalcutpro.ui.Button")
local Table								= require("hs.finalcutpro.ui.Table")
local ScrollArea						= require("hs.finalcutpro.ui.ScrollArea")
local CheckBox							= require("hs.finalcutpro.ui.CheckBox")
local PopUpButton						= require("hs.finalcutpro.ui.PopUpButton")
local TextField							= require("hs.finalcutpro.ui.TextField")

local GeneratorsBrowser = {}

GeneratorsBrowser.TITLE = "Titles and Generators"

function GeneratorsBrowser:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function GeneratorsBrowser:parent()
	return self._parent
end

function GeneratorsBrowser:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- GeneratorsBrowser UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function GeneratorsBrowser:UI()
	if self:isShowing() then
		return axutils.cache(self, "_ui", function()
			return self:parent():UI()
		end)
	end
	return nil
end

function GeneratorsBrowser:isShowing()
	return self:parent():showGenerators():isChecked()
end

function GeneratorsBrowser:show()
	local menuBar = self:app():menuBar()
	-- Go there direct
	menuBar:selectMenu("Window", "Go To", GeneratorsBrowser.TITLE)
	just.doUntil(function() return self:isShowing() end)
	return self
end

function GeneratorsBrowser:hide()
	self:parent():hide()
	return self
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Sections
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function GeneratorsBrowser:mainGroupUI()
	return axutils.cache(self, "_mainGroup",
	function()
		local ui = self:UI()
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end)
end

function GeneratorsBrowser:sidebar()
	if not self._sidebar then
		self._sidebar = Table:new(self, function()
			return axutils.childWithID(self:mainGroupUI(), "_NS:9")
		end):uncached()
	end
	return self._sidebar
end

function GeneratorsBrowser:contents()
	if not self._contents then
		self._contents = ScrollArea:new(self, function()
			local group = axutils.childMatching(self:mainGroupUI(), function(child)
				return child:role() == "AXGroup" and #child == 1
			end)
			return group and group[1]
		end)
	end
	return self._contents
end

function GeneratorsBrowser:group()
	if not self._group then
		self._group = PopUpButton:new(self, function()
			return axutils.childWithRole(self:UI(), "AXPopUpButton")
		end)
	end
	return self._group
end

function GeneratorsBrowser:search()
	if not self._search then
		self._search = TextField:new(self, function()
			return axutils.childWithRole(self:mainGroupUI(), "AXTextField")
		end)
	end
	return self._search
end

function GeneratorsBrowser:showSidebar()
	self:app():menuBar():checkMenu("Window", "Show in Workspace", "Sidebar")
end

function GeneratorsBrowser:topCategoriesUI()
	return self:sidebar():rowsUI(function(row)
		return row:attributeValue("AXDisclosureLevel") == 0
	end)
end

function GeneratorsBrowser:showInstalledTitles()
	self:group():selectItem(1)
	return self
end

function GeneratorsBrowser:showInstalledGenerators()
	self:showInstalledTitles()
	return self
end

function GeneratorsBrowser:showAllTitles()
	self:showSidebar()
	local topCategories = self:topCategoriesUI()
	if topCategories and #topCategories == 2 then
		self:sidebar():selectRow(topCategories[1])
	end
	return self
end

function GeneratorsBrowser:showAllGenerators()
	self:showSidebar()
	local topCategories = self:topCategoriesUI()
	if topCategories and #topCategories == 2 then
		self:sidebar():selectRow(topCategories[2])
	end
	return self
end


function GeneratorsBrowser:currentItemsUI()
	return self:contents():childrenUI()
end

function GeneratorsBrowser:selectedItemsUI()
	return self:contents():selectedChildrenUI()
end

function GeneratorsBrowser:itemIsSelected(itemUI)
	local selectedItems = self:selectedItemsUI()
	if selectedItems and #selectedItems > 0 then
		for _,selected in ipairs(selectedItems) do
			if selected == itemUI then
				return true
			end
		end
	end
	return false
end

function GeneratorsBrowser:applyItem(itemUI)
	if itemUI then
		self:contents():showChild(itemUI)
		local targetPoint = geometry.rect(itemUI:frame()).center
		tools.ninjaDoubleClick(targetPoint)
	end
	return self
end

--- Returns the list of titles for all effects/transitions currently visible
function GeneratorsBrowser:getCurrentTitles()
	local contents = self:contents():childrenUI()
	if contents ~= nil then
		return fnutils.map(contents, function(child)
			return child:attributeValue("AXTitle")
		end)
	end
	return nil
end

-------- Layouts ---------------

function GeneratorsBrowser:saveLayout()
	local layout = {}
	if self:isShowing() then
		layout.showing = true
		layout.sidebar = self:sidebar():saveLayout()
		layout.contents = self:contents():saveLayout()
		layout.search = self:search():saveLayout()
	end
	return layout
end

function GeneratorsBrowser:loadLayout(layout)
	if layout and layout.showing then
		self:show()
		self:search():loadLayout(layout.search)
		self:sidebar():loadLayout(layout.sidebar)
		self:contents():loadLayout(layout.contents)
	end
end

return GeneratorsBrowser