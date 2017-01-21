local axutils						= require("hs.finalcutpro.axutils")

local Alert = {}

function Alert.matches(element)
	if element then
		return element:attributeValue("AXRole") == "AXSheet"
	end
	return false
end


function Alert:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Alert:parent()
	return self._parent
end

function Alert:app()
	return self:parent():app()
end

function Alert:UI()
	return axutils.cache(self, "_ui", function()
		axutils.childMatching(self:parent():UI(), Alert.matches)
	end,
	Alert.matches)
end

function Alert:isShowing()
	return self:UI() ~= nil
end

function Alert:hide()
	self:pressCancel()
end

function Alert:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
		end
	end
	return self
end

function Alert:pressDefault()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
		end
	end
	return self
end

function Alert:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

return Alert