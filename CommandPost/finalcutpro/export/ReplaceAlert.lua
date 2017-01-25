local axutils						= require("hs.finalcutpro.axutils")

local ReplaceAlert = {}

function ReplaceAlert.matches(element)
	if element then
		return element:attributeValue("AXRole") == "AXSheet"			-- it's a sheet
		   and axutils.childWithRole(element, "AXTextField") == nil 	-- with no text fields
	end
	return false
end


function ReplaceAlert:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ReplaceAlert:parent()
	return self._parent
end

function ReplaceAlert:app()
	return self:parent():app()
end

function ReplaceAlert:UI()
	return axutils.cache(self, "_ui", function()
		return axutils.childMatching(self:parent():UI(), ReplaceAlert.matches)
	end,
	ReplaceAlert.matches)
end

function ReplaceAlert:isShowing()
	return self:UI() ~= nil
end

function ReplaceAlert:hide()
	self:pressCancel()
end

function ReplaceAlert:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
		end
	end
	return self
end

function ReplaceAlert:pressReplace()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
		end
	end
	return self
end

function ReplaceAlert:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

return ReplaceAlert