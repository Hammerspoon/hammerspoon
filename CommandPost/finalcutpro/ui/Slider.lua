local axutils						= require("hs.finalcutpro.axutils")

local Slider = {}

function Slider.matches(element)
	return element:attributeValue("AXRole") == "AXSlider"
end

--- hs.finalcutpro.ui.Slider:new(axuielement, function) -> Slider
--- Function:
--- Creates a new Slider
function Slider:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Slider:parent()
	return self._parent
end

function Slider:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	Slider.matches)
end

function Slider:getValue()
	local ui = self:UI()
	return ui and ui:attributeValue("AXValue")
end

function Slider:setValue(value)
	local ui = self:UI()
	if ui then
		ui:setAttributeValue("AXValue", value)
	end
	return self
end

function Slider:getMinValue()
	local ui = self:UI()
	return ui and ui:attributeValue("AXMinValue")
end

function Slider:getMaxValue()
	local ui = self:UI()
	return ui and ui:attributeValue("AXMaxValue")
end

function Slider:increment()
	local ui = self:UI()
	if ui then
		ui:doIncrement()
	end
	return self
end

function Slider:decrement()
	local ui = self:UI()
	if ui then
		ui:doDecrement()
	end
	return self
end

function Slider:isEnabled()
	local ui = self:UI()
	return ui and ui:enabled()
end

function Slider:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

function Slider:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return Slider