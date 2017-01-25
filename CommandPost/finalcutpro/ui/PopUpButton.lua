local axutils						= require("hs.finalcutpro.axutils")

local PopUpButton = {}

function PopUpButton.matches(element)
	return element:attributeValue("AXRole") == "AXPopUpButton"
end

--- hs.finalcutpro.ui.PopUpButton:new(axuielement, function) -> PopUpButton
--- Function:
--- Creates a new PopUpButton
function PopUpButton:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PopUpButton:parent()
	return self._parent
end

function PopUpButton:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	PopUpButton.matches)
end

function PopUpButton:selectItem(index)
	local ui = self:UI()
	if ui then
		local items = ui:doPress()[1]
		local item = items[index]
		if item then
			-- select the menu item
			item:doPress()
		else
			-- close the menu again
			items:doCancel()
		end
	end
	return self
end

function PopUpButton:getValue()
	local ui = self:UI()
	return ui and ui:value()
end

function PopUpButton:setValue(value)
	local ui = self:UI()
	if ui and not ui:value() == value then
		local items = ui:doPress()[1]
		for i,item in items do
			if item:title() == value then
				item:doPress()
				return
			end
		end
		items:doCancel()
	end
	return self
end

function PopUpButton:isEnabled()
	local ui = self:UI()
	return ui and ui:enabled()
end

function PopUpButton:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

function PopUpButton:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

function PopUpButton:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return PopUpButton