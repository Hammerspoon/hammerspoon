local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")

local Button = {}

function Button.matches(element)
	return element and element:attributeValue("AXRole") == "AXButton"
end

--- hs.finalcutpro.ui.Button:new(axuielement, table) -> Button
--- Function:
--- Creates a new Button
function Button:new(parent, finderFn)
	o = {_parent = parent, _finder = finderFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Button:parent()
	return self._parent
end

function Button:UI()
	return axutils.cache(self, "_ui", function()
		return self._finder()
	end,
	Button.matches)
end

function Button:isEnabled()
	return self:UI():enabled()
end

function Button:press()
	self:UI():doPress()
	return self
end

return Button