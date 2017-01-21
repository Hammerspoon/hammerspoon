local axutils						= require("hs.finalcutpro.axutils")

local TextField = {}

function TextField.matches(element)
	return element:attributeValue("AXRole") == "AXTextField"
end

--- hs.finalcutpro.ui.TextField:new(axuielement, function) -> TextField
--- Function:
--- Creates a new TextField
function TextField:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function TextField:parent()
	return self._parent
end

function TextField:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	TextField.matches)
end

function TextField:isShowing()
	return self:UI() ~= nil
end

function TextField:getValue()
	local ui = self:UI()
	return ui and ui:attributeValue("AXValue")
end

function TextField:setValue(value)
	local ui = self:UI()
	if ui then
		ui:setAttributeValue("AXValue", value)
		ui:performAction("AXConfirm")
	end
	return self
end

function TextField:clear()
	self:setValue("")
end

function TextField:isEnabled()
	local ui = self:UI()
	return ui and ui:enabled()
end

function TextField:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

function TextField:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return TextField