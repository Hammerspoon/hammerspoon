local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local geometry							= require("hs.geometry")
local fnutils							= require("hs.fnutils")
local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local Playhead							= require("hs.finalcutpro.main.Playhead")

local TimelineContents = {}

function TimelineContents.matches(element)
	return element
	    and element:attributeValue("AXIdentifier") == "_NS:16"
		and element:attributeValue("AXRole") == "AXLayoutArea"
		and element:attributeValueCount("AXAuditIssues") < 1
end

function TimelineContents:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function TimelineContents:parent()
	return self._parent
end

function TimelineContents:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE CONTENT UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function TimelineContents:UI()
	return axutils.cache(self, "_ui", function()
		local scrollArea = self:scrollAreaUI()
		if scrollArea then
			return axutils.childMatching(scrollArea, TimelineContents.matches)
		end
		return nil
	end,
	TimelineContents.matches)
end

function TimelineContents:scrollAreaUI()
	local main = self:parent():mainUI()
	if main then
		return axutils.childMatching(main, function(child)
			if child:attributeValue("AXIdentifier") == "_NS:9" and child:attributeValue("AXRole") == "AXScrollArea" then
				return axutils.childMatching(child:attributeValue("AXContents"), TimelineContents.matches) ~= nil
			end
			return false
		end)
	end
	return nil
end

function TimelineContents:isShowing()
	return self:UI() ~= nil
end

function TimelineContents:show()
	self:parent():show()
	return self
end

function TimelineContents:hide()
	self:parent():hide()
	return self
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PLAYHEAD
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function TimelineContents:playhead()
	if not self._playhead then
		self._playhead = Playhead:new(self, false, function()
			return self:UI()
		end)
	end
	return self._playhead
end

function TimelineContents:skimmingPlayhead()
	if not self._skimmingPlayhead then
		self._skimmingPlayhead = Playhead:new(self, true)
	end
	return self._skimmingPlayhead
end

function TimelineContents:horizontalScrollBarUI()
	local ui = self:scrollAreaUI()
	return ui and ui:attributeValue("AXHorizontalScrollBar")
end

function TimelineContents:verticalScrollBarUI()
	local ui = self:scrollAreaUI()
	return ui and ui:attributeValue("AXVerticalScrollBar")
end

function TimelineContents:viewFrame()
	local ui = self:scrollAreaUI()

	if not ui then return nil end

	local hScroll = self:horizontalScrollBarUI()
	local vScroll = self:verticalScrollBarUI()

	local frame = ui:frame()

	if hScroll then
		frame.h = frame.h - hScroll:frame().h
	end

	if vScroll then
		frame.w = frame.w - vScroll:frame().w
	end
	return frame
end

function TimelineContents:timelineFrame()
	local ui = self:UI()
	return ui and ui:frame()
end

function TimelineContents:scrollHorizontalBy(shift)
	local ui = self:horizontalScrollBarUI()
	if ui then
		local indicator = ui[1]
		local value = indicator:attributeValue("AXValue")
		indicator:setAttributeValue("AXValue", value + shift)
	end
end

function TimelineContents:scrollHorizontalTo(value)
	local ui = self:horizontalScrollBarUI()
	if ui then
		local indicator = ui[1]
		value = math.max(0, math.min(1, value))
		if indicator:attributeValue("AXValue") ~= value then
			indicator:setAttributeValue("AXValue", value)
		end
	end
end

function TimelineContents:getScrollHorizontal()
	local ui = self:horizontalScrollBarUI()
	return ui and ui[1] and ui[1]:attributeValue("AXValue")
end

function TimelineContents:scrollVerticalBy(shift)
	local ui = self:verticalScrollBarUI()
	if ui then
		local indicator = ui[1]
		local value = indicator:attributeValue("AXValue")
		indicator:setAttributeValue("AXValue", value + shift)
	end
end

function TimelineContents:scrollVerticalTo(value)
	local ui = self:verticalScrollBarUI()
	if ui then
		local indicator = ui[1]
		value = math.max(0, math.min(1, value))
		if indicator:attributeValue("AXValue") ~= value then
			indicator:setAttributeValue("AXValue", value)
		end
	end
end

function TimelineContents:getScrollVertical()
	local ui = self:verticalScrollBarUI()
	return ui and ui[1] and ui[1]:attributeValue("AXValue")
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- CLIPS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

--- hs.finalcutpro.main.TimelineContents:selectedClipsUI(expandedGroups, filterFn) -> table of axuielements
--- Function
--- Returns a table containing the list of selected clips.
---
--- If `expandsGroups` is true any AXGroup items will be expanded to the list of contained AXLayoutItems.
---
--- If `filterFn` is provided it will be called with a single argument to check if the provided
--- clip should be included in the final table.
---
--- Parameters:
---  * expandGroups	- (optional) if true, expand AXGroups to include contained AXLayoutItems
---  * filterFn		- (optional) if provided, the function will be called to check each clip
---
--- Returns:
---  * The table of selected axuielements that match the conditions
---
function TimelineContents:selectedClipsUI(expandGroups, filterFn)
	local ui = self:UI()
	if ui then
		local clips = ui:attributeValue("AXSelectedChildren")
		return self:_filterClips(clips, expandGroups, filterFn)
	end
	return nil
end

--- hs.finalcutpro.main.TimelineContents:clipsUI(expandedGroups, filterFn) -> table of axuielements
--- Function
--- Returns a table containing the list of clips in the Timeline.
---
--- If `expandsGroups` is true any AXGroup items will be expanded to the list of contained AXLayoutItems.
---
--- If `filterFn` is provided it will be called with a single argument to check if the provided
--- clip should be included in the final table.
---
--- Parameters:
---  * expandGroups	- (optional) if true, expand AXGroups to include contained AXLayoutItems
---  * filterFn		- (optional) if provided, the function will be called to check each clip
---
--- Returns:
---  * The table of axuielements that match the conditions
---
function TimelineContents:clipsUI(expandGroups, filterFn)
	local ui = self:UI()
	if ui then
		local clips = fnutils.filter(ui:children(), function(child)
			local role = child:attributeValue("AXRole")
			return role == "AXLayoutItem" or role == "AXGroup"
		end)
		return self:_filterClips(clips, expandGroups, filterFn)
	end
	return nil
end

--- hs.finalcutpro.main.TimelineContents:playheadClipsUI(expandedGroups, filterFn) -> table of axuielements
--- Function
--- Returns a table array containing the list of clips in the Timeline under the playhead, ordered with the
--- highest clips at the beginning of the array.
---
--- If `expandsGroups` is true any AXGroup items will be expanded to the list of contained `AXLayoutItems`.
---
--- If `filterFn` is provided it will be called with a single argument to check if the provided
--- clip should be included in the final table.
---
--- Parameters:
---  * expandGroups	- (optional) if true, expand AXGroups to include contained AXLayoutItems
---  * filterFn		- (optional) if provided, the function will be called to check each clip
---
--- Returns:
---  * The table of axuielements that match the conditions
---
function TimelineContents:playheadClipsUI(expandGroups, filterFn)
	local playheadPosition = self:playhead():getPosition()
	local clips = self:clipsUI(expandGroups, function(clip)
		local frame = clip:frame()
		return frame and playheadPosition >= frame.x and playheadPosition <= (frame.x + frame.w)
		   and (filterFn == nil or filterFn(clip))
	end)
	table.sort(clips, function(a, b) return a:position().y < b:position().y end)
	return clips
end

function TimelineContents:_filterClips(clips, expandGroups, filterFn)
	if expandGroups then
		return self:_expandClips(clips, filterFn)
	elseif filterFn ~= nil then
		return fnutils.filter(clips, filterFn)
	else
		return clips
	end
end

function TimelineContents:_expandClips(clips, filterFn)
	return fnutils.mapCat(clips, function(child)
		local role = child:attributeValue("AXRole")
		if role == "AXLayoutItem" then
			if filterFn == nil or filterFn(child) then
				return {child}
			end
		elseif role == "AXGroup" then
			return self:_expandClips(child:attributeValue("AXChildren"), filterFn)
		end
		return {}
	end)
end

function TimelineContents:selectClips(clipsUI)
	local ui = self:UI()
	if ui then
		local selectedClips = {}
		for i,clip in ipairs(clipsUI) do
			selectedClips[i] = clip
		end
		ui:setAttributeValue("AXSelectedChildren", selectedClips)
	end
	return self
end

function TimelineContents:selectClip(clipUI)
	return self:selectClips({clipUI})
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- MULTICAM ANGLE EDITOR
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function TimelineContents:anglesUI()
	return self:clipsUI()
end

function TimelineContents:angleButtonsUI(angleNumber)
	local angles = self:anglesUI()
	if angles then
		local angle = angles[angleNumber]
		if angle then
			return axutils.childrenWithRole(angle, "AXButton")
		end
	end
	return nil
end

function TimelineContents:monitorVideoInAngle(angleNumber)
	local buttons = self:angleButtonsUI(angleNumber)
	if buttons and buttons[1] then
		buttons[1]:doPress()
	end
end

function TimelineContents:toggleAudioInAngle(angleNumber)
	local buttons = self:angleButtonsUI(angleNumber)
	if buttons and buttons[2] then
		buttons[2]:doPress()
	end
end

-- Selects the clip under the playhead in the specified angle.
-- NOTE: This will only work in multicam clips
function TimelineContents:selectClipInAngle(angleNumber)
	local clipsUI = self:anglesUI()
	if clipsUI then
		local angleUI = clipsUI[angleNumber]

		local playheadPosition = self:playhead():getPosition()
		local clipUI = axutils.childMatching(angleUI, function(child)
			local frame = child:frame()
			return child:attributeValue("AXRole") == "AXLayoutItem"
			   and frame.x <= playheadPosition and (frame.x+frame.w) >= playheadPosition
		end)

		self:monitorVideoInAngle(angleNumber)

		if clipUI then
			self:selectClip(clipUI)
		else
			debugMessage("Unable to find the clip under the playhead for angle "..angleNumber..".")
		end
	end
	return self
end

return TimelineContents