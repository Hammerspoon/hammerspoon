local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")
local timer								= require("hs.timer")

local TimelineContent					= require("hs.finalcutpro.main.TimelineContents")
local TimelineToolbar					= require("hs.finalcutpro.main.TimelineToolbar")
local PrimaryWindow						= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("hs.finalcutpro.main.SecondaryWindow")
local EffectsBrowser					= require("hs.finalcutpro.main.EffectsBrowser")

local Timeline = {}

function Timeline.matches(element)
	return element:attributeValue("AXRole") == "AXGroup"
	   and axutils.childWith(element, "AXIdentifier", "_NS:237") ~= nil
end

function Timeline:new(app)
	o = {_app = app}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Timeline:app()
	return self._app
end

function Timeline:isOnSecondary()
	local ui = self:UI()
	return ui and SecondaryWindow.matches(ui:window())
end

function Timeline:isOnPrimary()
	local ui = self:UI()
	return ui and PrimaryWindow.matches(ui:window())
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:UI()
	return axutils.cache(self, "_ui", function()
		local app = self:app()
		return Timeline._findTimeline(app:secondaryWindow(), app:primaryWindow())
	end,
	Timeline.matches)
end

function Timeline._findTimeline(...)
	for i = 1,select("#", ...) do
		local window = select(i, ...)
		if window then
			local ui = window:timelineGroupUI()
			if ui then
				local timeline = axutils.childMatching(ui, Timeline.matches)
				if timeline then return timeline end
			end
		end
	end
	return nil
end

function Timeline:isShowing()
	local ui = self:UI()
	return ui ~= nil and #ui > 0
end

function Timeline:show()
	if not self:isShowing() then
		self:showOnPrimary()
	end
end

function Timeline:showOnPrimary()
	local menuBar = self:app():menuBar()

	-- if the timeline is on the secondary, we need to turn it off before enabling in primary
	menuBar:uncheckMenu("Window", "Show in Secondary Display", "Timeline")
	-- Then enable it in the primary
	menuBar:checkMenu("Window", "Show in Workspace", "Timeline")

	return self
end

function Timeline:showOnSecondary()
	local menuBar = self:app():menuBar()

	-- if the timeline is on the secondary, we need to turn it off before enabling in primary
	menuBar:checkMenu("Window", "Show in Secondary Display", "Timeline")

	return self
end


function Timeline:hide()
	local menuBar = self:app():menuBar()
	-- Uncheck it from the primary workspace
	menuBar:uncheckMenu("Window", "Show in Secondary Display", "Timeline")
	menuBar:uncheckMenu("Window", "Show in Workspace", "Timeline")
	return self
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- MAIN UI
--- The Canvas is the main body of the timeline, containing the
--- Timeline Index, the canvas, and the Effects/Transitions panels.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:mainUI()
	return axutils.cache(self, "_main", function()
		local ui = self:UI()
		return ui and axutils.childMatching(ui, Timeline.matchesMain)
	end,
	Timeline.matchesMain)
end

function Timeline.matchesMain(element)
	return element:attributeValue("AXIdentifier") == "_NS:237"
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- CONTENT
--- The Content is the main body of the timeline, containing the
--- Timeline Index, the Content, and the Effects/Transitions panels.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:contents()
	if not self._content then
		self._content = TimelineContent:new(self)
	end
	return self._content
end


-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- EFFECT BROWSER
--- The (sometimes hidden) Effect Browser.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:effects()
	if not self._effects then
		self._effects = EffectsBrowser:new(self, EffectsBrowser.EFFECTS)
	end
	return self._effects
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TRANSITIONS BROWSER
--- The (sometimes hidden) Transitions Browser.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:transitions()
	if not self._transitions then
		self._transitions = EffectsBrowser:new(self, EffectsBrowser.TRANSITIONS)
	end
	return self._transitions
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PLAYHEAD
--- The timeline Playhead.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:playhead()
	return self:contents():playhead()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PLAYHEAD
--- The Playhead that tracks under the mouse while skimming.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:skimmingPlayhead()
	return self:contents():skimmingPlayhead()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TOOLBAR
--- The bar at the top of the timeline.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Timeline:toolbar()
	if not self._toolbar then
		self._toolbar = TimelineToolbar:new(self)
	end
	return self._toolbar
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PLAYHEAD LOCKING
--- If the playhead is locked, it will be kept as close to the middle
--- of the timeline view panel as possible at all times.
-----------------------------------------------------------------------
-----------------------------------------------------------------------

Timeline.lockActive = 0.01
Timeline.lockInactive = 0.1
Timeline.stopThreshold = 15

Timeline.STOPPED = 1
Timeline.TRACKING = 2
Timeline.DEADZONE = 3
Timeline.INVISIBLE = 4

function Timeline:lockPlayhead(deactivateWhenStopped, lockInCentre)
	if self._locked then
		-- already locked.
		return self
	end

	local content = self:contents()
	local playhead = content:playhead()
	local check = nil
	local status = 0
	local lastPosition = nil
	local stopCounter = 0
	local originalOffset = 0

	local incPlayheadStopped = function()
		stopCounter = math.min(Timeline.stopThreshold, stopCounter + 1)
	end

	local playheadHasStopped = function()
		return stopCounter == Timeline.stopThreshold
	end

	-- Setting this to false unlocks the playhead.
	self._locked = true

	-- Calculate the original offset of the playhead
	local viewFrame = content:viewFrame()
	if viewFrame then
		originalOffset = playhead:getPosition() - viewFrame.x
		if lockInCentre or originalOffset <= 0 or originalOffset >= viewFrame.w then
			-- align the playhead to the centre of the timeline view
			originalOffset = math.floor(viewFrame.w/2)
		end
	end

	-- Create the 'check' function that will loop to keep the playhead in position
	check = function()
		if not self._locked then
			-- We have stopped locking. Bail.
			return
		end

		local viewFrame = content:viewFrame()
		local playheadPosition = playhead:getPosition()

		if viewFrame == nil or playheadPosition == nil then
			-- The timeline and/or playhead does not exist.
			if status ~= Timeline.INVISIBLE then
				status = Timeline.INVISIBLE
				debugMessage("Timeline not visible.")
			end

			stopCounter = Timeline.stopThreshold
			if deactivateWhenStopped then
				debugMessage("Deactivating lock.")
				self:unlockPlayhead()
			end
		else
			-- The timeline is visible. Let's track it!
			-- Reset the original offset if the viewFrame gets too narrow
			if originalOffset >= viewFrame.w then originalOffset = math.floor(viewFrame.w/2) end
			-- Calculate the target offset
			local targetPosition = viewFrame.x + originalOffset

			if playheadPosition == lastPosition then
				-- it hasn't moved since the last check
				incPlayheadStopped()
				if playheadHasStopped() and status ~= Timeline.STOPPED then
					status = Timeline.STOPPED
					debugMessage("Playhead stopped.")
					if deactivateWhenStopped then
						debugMessage("Deactivating lock.")
						self:unlockPlayhead()
					end
				end
			else
				-- it's moving
				local timelineFrame = content:timelineFrame()
				local scrollWidth = timelineFrame.w - viewFrame.w
				local scrollPoint = timelineFrame.x*-1 + viewFrame.x + playheadPosition - targetPosition
				local scrollTarget = scrollPoint/scrollWidth
				local scrollValue = content:getScrollHorizontal()

				stopCounter = 0

				if scrollTarget < 0 and scrollValue == 0 or scrollTarget > 1 and scrollValue == 1 then
					if status ~= Timeline.DEADZONE then
						status = Timeline.DEADZONE
						debugMessage("In the deadzone.")
					end
				else
					if status ~= Timeline.TRACKING then
						status = Timeline.TRACKING
						debugMessage("Tracking the playhead.")
					end
					content:scrollHorizontalTo(scrollTarget)
				end
			end
		end

		-- Check how quickly we should check again.
		local next = Timeline.lockActive
		if playheadHasStopped() then
			next = Timeline.lockInactive
		end

		-- Update last postion to the current position.
		lastPosition = playheadPosition

		if next ~= nil then
			timer.doAfter(next, check)
		end
	end

	check()

	return self
end

function Timeline:unlockPlayhead()
	self._locked = false

	return self
end

function Timeline:isLockedPlayhead()
	return self._locked
end

return Timeline