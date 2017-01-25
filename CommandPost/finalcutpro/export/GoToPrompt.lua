local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")
local eventtap						= require("hs.eventtap")

local GoToPrompt = {}

function GoToPrompt.matches(element)
	if element then
		return element:attributeValue("AXRole") == "AXSheet"			-- it's a sheet
		   and (axutils.childWithRole(element, "AXTextField") ~= nil 	-- with a text field
		    or axutils.childWithRole(element, "AXComboBox") ~= nil)
	end
	return false
end

function GoToPrompt:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function GoToPrompt:parent()
	return self._parent
end

function GoToPrompt:app()
	return self:parent():app()
end

function GoToPrompt:UI()
	return axutils.cache(self, "_ui", function()
		return axutils.childMatching(self:parent():UI(), GoToPrompt.matches)
	end,
	GoToPrompt.matches)
end

function GoToPrompt:show()
	if self:parent():isShowing() then
		eventtap.keyStroke({"cmd", "shift"}, "g")
		just.doUntil(function() return self:isShowing() end)
	end
	return self
end

function GoToPrompt:isShowing()
	return self:UI() ~= nil
end

function GoToPrompt:hide()
	self:pressCancel()
end

function GoToPrompt:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
			just.doWhile(function() return self:isShowing() end)
		end
	end
	return self
end

function GoToPrompt:setValue(value)
	local textField = axutils.childWithRole(self:UI(), "AXTextField")
	if textField then
		textField:setAttributeValue("AXValue", value)
	else
		local comboBox = axutils.childWithRole(self:UI(), "AXComboBox")
		if comboBox then
			comboBox:setAttributeValue("AXValue", value)
		end
	end
	return self
end

function GoToPrompt:pressDefault()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
			just.doWhile(function() return self:isShowing() end)
		end
	end
	return self
end

function GoToPrompt:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

return GoToPrompt