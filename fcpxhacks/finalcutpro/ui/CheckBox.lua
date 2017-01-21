local axutils						= require("hs.finalcutpro.axutils")

local CheckBox = {}

function CheckBox.matches(element)
	return element:attributeValue("AXRole") == "AXCheckBox"
end

--- hs.finalcutpro.ui.CheckBox:new(axuielement, function) -> CheckBox
--- Function:
--- Creates a new CheckBox
function CheckBox:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CheckBox:parent()
	return self._parent
end

function CheckBox:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	CheckBox.matches)
end

function CheckBox:isChecked()
	local ui = self:UI()
	return ui and ui:value() == 1
end

function CheckBox:check()
	local ui = self:UI()
	if ui and ui:value() == 0 then
		ui:doPress()
	end
	return self
end

function CheckBox:uncheck()
	local ui = self:UI()
	if ui and ui:value() == 1 then
		ui:doPress()
	end
	return self
end

function CheckBox:toggle()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

function CheckBox:isEnabled()
	local ui = self:UI()
	return ui and ui:enabled()
end

function CheckBox:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

function CheckBox:saveLayout()
	return {
		checked = self:isChecked()
	}
end

function CheckBox:loadLayout(layout)
	if layout then
		if layout.checked then
			self:check()
		else
			self:uncheck()
		end
	end
end

return CheckBox