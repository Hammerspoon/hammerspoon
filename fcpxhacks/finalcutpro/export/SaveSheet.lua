local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")
local windowfilter					= require("hs.window.filter")

local ReplaceAlert					= require("hs.finalcutpro.export.ReplaceAlert")
local GoToPrompt					= require("hs.finalcutpro.export.GoToPrompt")

local TextField							= require("hs.finalcutpro.ui.TextField")

local SaveSheet = {}

function SaveSheet.matches(element)
	if element then
		return element:attributeValue("AXRole") == "AXSheet"
	end
	return false
end


function SaveSheet:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function SaveSheet:parent()
	return self._parent
end

function SaveSheet:app()
	return self:parent():app()
end

function SaveSheet:UI()
	return axutils.cache(self, "_ui", function()
		return axutils.childMatching(self:parent():UI(), SaveSheet.matches)
	end,
	SaveSheet.matches)
end

function SaveSheet:isShowing()
	return self:UI() ~= nil or self:replaceAlert():isShowing()
end

function SaveSheet:hide()
	self:pressCancel()
end

function SaveSheet:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
		end
	end
	return self
end

function SaveSheet:pressSave()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
		end
	end
	return self
end

function SaveSheet:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

function SaveSheet:filename()
	if not self._filename then
		self._filename = TextField:new(self, function()
			return axutils.childWithRole(self:UI(), "AXTextField")
		end)
	end
	return self._filename
end

function SaveSheet:setPath(path)
	if self:isShowing() then
		-- Display the 'Go To' prompt
		self:goToPrompt():show():setValue(path):pressDefault()
	end
	return self
end

function SaveSheet:replaceAlert()
	if not self._replaceAlert then
		self._replaceAlert = ReplaceAlert:new(self)
	end
	return self._replaceAlert
end

function SaveSheet:goToPrompt()
	if not self._goToPrompt then
		self._goToPrompt = GoToPrompt:new(self)
	end
	return self._goToPrompt
end


return SaveSheet