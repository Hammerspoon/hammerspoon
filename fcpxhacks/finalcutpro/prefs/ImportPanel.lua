local log								= require("hs.logger").new("playback")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local ImportPanel = {}

ImportPanel.ID = 4

ImportPanel.CREATE_PROXY_MEDIA 			= "_NS:177"
ImportPanel.CREATE_OPTIMIZED_MEDIA 		= "_NS:15"
ImportPanel.COPY_TO_MEDIA_FOLDER 		= "_NS:84"

function ImportPanel:new(preferencesDialog)
	o = {_parent = preferencesDialog}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ImportPanel:parent()
	return self._parent
end

function ImportPanel:UI()
	return axutils.cache(self, "_ui", function()
		local toolbarUI = self:parent():toolbarUI()
		return toolbarUI and toolbarUI[ImportPanel.ID]
	end)
end

function ImportPanel:isShowing()
	if self:parent():isShowing() then
		local toolbar = self:parent():toolbarUI()
		if toolbar then
			local selected = toolbar:selectedChildren()
			return #selected == 1 and selected[1] == toolbar[ImportPanel.ID]
		end
	end
	return false
end

function ImportPanel:show()
	local parent = self:parent()
	-- show the parent.
	if parent:show() then
		-- get the toolbar UI
		local panel = just.doUntil(function() return self:UI() end)
		if panel then
			panel:doPress()
			return true
		end
	end
	return false
end

function ImportPanel:toggleCheckBox(identifier)
	if self:show() then
		local group = self:parent():groupUI()
		if group then
			local checkbox = axutils.childWith(group, "AXIdentifier", identifier)
			if checkbox then
				checkbox:doPress()
				return true
			end
		end
	end
	return false
end

function ImportPanel:toggleCreateProxyMedia()
	return self:toggleCheckBox(ImportPanel.CREATE_PROXY_MEDIA)
end

function ImportPanel:toggleCreateOptimizedMedia()
	return self:toggleCheckBox(ImportPanel.CREATE_OPTIMIZED_MEDIA)
end

function ImportPanel:toggleCopyToMediaFolder()
	if self:show() then
		local group = self:parent():groupUI()
		if group then
			local radioGroup = axutils.childWith(group, "AXIdentifier", ImportPanel.COPY_TO_MEDIA_FOLDER)
			if radioGroup then
				for i,button in ipairs(radioGroup) do
					if button:value() == 0 then
						button:doPress()
						return true
					end
				end
			end
		end
	end
	return false
end


return ImportPanel