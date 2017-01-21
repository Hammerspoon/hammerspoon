local axutils						= require("hs.finalcutpro.axutils")

local RadioButton = {}

function RadioButton.matches(element)
	return element:attributeValue("AXRole") == "AXRadioButton"
end

--- hs.finalcutpro.ui.RadioButton:new(axuielement, function) -> RadioButton
--- Function:
--- Creates a new RadioButton
function RadioButton:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function RadioButton:parent()
	return self._parent
end

function RadioButton:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	RadioButton.matches)
end

function RadioButton:isChecked()
	local ui = self:UI()
	return ui and ui:value() == 1
end

function RadioButton:check()
	local ui = self:UI()
	if ui and ui:value() == 0 then
		ui:doPress()
	end
	return self
end

function RadioButton:uncheck()
	local ui = self:UI()
	if ui and ui:value() == 1 then
		ui:doPress()
	end
	return self
end

function RadioButton:toggle()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

function RadioButton:isEnabled()
	local ui = self:UI()
	return ui and ui:enabled()
end

function RadioButton:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

function RadioButton:saveLayout()
	return {
		checked = self:isChecked()
	}
end

function RadioButton:loadLayout(layout)
	if layout then
		if layout.checked then
			self:check()
		else
			self:uncheck()
		end
	end
end

return RadioButton