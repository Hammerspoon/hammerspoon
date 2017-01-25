local axutils							= require("hs.finalcutpro.axutils")

local CheckBox							= require("hs.finalcutpro.ui.CheckBox")
local RadioButton						= require("hs.finalcutpro.ui.RadioButton")

local TimelineAppearance				= require("hs.finalcutpro.main.TimelineAppearance")

local TimelineToolbar = {}

function TimelineToolbar.matches(element)
	return element and element:attributeValue("AXIdentifier") ~= "_NS:237"
end

function TimelineToolbar:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function TimelineToolbar:parent()
	return self._parent
end

function TimelineToolbar:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function TimelineToolbar:UI()
	return axutils.cache(self, "_ui", function()
		return axutils.childMatching(self:parent():UI(), TimelineToolbar.matches)
	end,
	TimelineToolbar.matches)
end

function TimelineToolbar:isShowing()
	return self:UI() ~= nil
end

-- Contains buttons relating to mouse skimming behaviour
function TimelineToolbar:skimmingGroupUI()
	return axutils.cache(self, "_skimmingGroup", function()
		return axutils.childWithID(self:UI(), "_NS:178")
	end)
end

function TimelineToolbar:effectsGroupUI()
	return axutils.cache(self, "_effectsGroup", function()
		return axutils.childWithID(self:UI(), "_NS:165")
	end)
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- THE BUTTONS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function TimelineToolbar:appearance()
	if not self._appearance then
		self._appearance = TimelineAppearance:new(self)
	end
	return self._appearance
end

function TimelineToolbar:effectsToggle()
	if not self._effectsToggle then
		self._effectsToggle = RadioButton:new(self, function()
			return self:effectsGroupUI()[1]
		end)
	end
	return self._effectsToggle
end

function TimelineToolbar:transitionsToggle()
	if not self._transitionsToggle then
		self._transitionsToggle = RadioButton:new(self, function()
			return self:effectsGroupUI()[2]
		end)
	end
	return self._transitionsToggle
end

return TimelineToolbar