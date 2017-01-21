local log								= require("hs.logger").new("playback")
local inspect							= require("hs.inspect")

local axutils							= require("hs.finalcutpro.axutils")
local just								= require("hs.just")

local PlaybackPanel = {}

PlaybackPanel.ID = 3

PlaybackPanel.CREATE_OPTIMIZED_MEDIA_FOR_MULTICAM_CLIPS = "_NS:145"
PlaybackPanel.AUTO_START_BG_RENDER = "_NS:15"

function PlaybackPanel:new(preferencesDialog)
	o = {_parent = preferencesDialog}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PlaybackPanel:parent()
	return self._parent
end

function PlaybackPanel:UI()
	return axutils.cache(self, "_ui", function()
		local toolbarUI = self:parent():toolbarUI()
		return toolbarUI and toolbarUI[PlaybackPanel.ID]
	end)
end

function PlaybackPanel:isShowing()
	if self:parent():isShowing() then
		local toolbar = self:parent():toolbarUI()
		if toolbar then
			local selected = toolbar:selectedChildren()
			return #selected == 1 and selected[1] == toolbar[PlaybackPanel.ID]
		end
	end
	return false
end

function PlaybackPanel:show()
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

function PlaybackPanel:toggleCheckBox(identifier)
	if self:show() then
		local group = self:parent():groupUI()
		if group then
			local checkbox = axutils.childWith(group, "AXIdentifier", identifier)
			checkbox:doPress()
			return true
		end
	end
	return false
end

function PlaybackPanel:toggleCreateOptimizedMediaForMulticamClips()
	return self:toggleCheckBox(PlaybackPanel.CREATE_OPTIMIZED_MEDIA_FOR_MULTICAM_CLIPS)
end

function PlaybackPanel:toggleAutoStartBGRender()
	return self:toggleCheckBox(PlaybackPanel.AUTO_START_BG_RENDER)
end

return PlaybackPanel