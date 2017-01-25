local axutils							= require("hs.finalcutpro.axutils")

local CheckBox							= require("hs.finalcutpro.ui.CheckBox")
local Slider							= require("hs.finalcutpro.ui.Slider")

local TimelineAppearance = {}

function TimelineAppearance.matches(element)
	return element and element:attributeValue("AXRole") == "AXPopover"
end

function TimelineAppearance:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function TimelineAppearance:parent()
	return self._parent
end

function TimelineAppearance:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- APPEARANCE POPOVER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function TimelineAppearance:toggleUI()
	return axutils.cache(self, "_toggleUI", function()
		return axutils.childWithID(self:parent():UI(), "_NS:154")
	end)
end

function TimelineAppearance:toggle()
	if not self._toggle then
		self._toggle = CheckBox:new(self, function()
			return self:toggleUI()
		end)
	end
	return self._toggle
end

function TimelineAppearance:UI()
	return axutils.cache(self, "_ui", function()
		return axutils.childMatching(self:toggleUI(), TimelineAppearance.matches)
	end,
	TimelineAppearance.matches)
end

function TimelineAppearance:show()
	if not self:isShowing() then
		self:toggle():check()
	end
	return self
end

function TimelineAppearance:hide()
	local ui = self:UI()
	if ui then
		ui:doCancel()
	end
	return self
end

function TimelineAppearance:isShowing()
	return self:UI() ~= nil
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- THE BUTTONS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function TimelineAppearance:clipHeight()
	if not self._clipHeight then
		self._clipHeight = Slider:new(self, function()
			return axutils.childWithID(self:UI(), "_NS:104")
		end)
	end
	return self._clipHeight
end

return TimelineAppearance