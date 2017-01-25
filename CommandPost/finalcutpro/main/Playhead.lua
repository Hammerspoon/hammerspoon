local axutils							= require("hs.finalcutpro.axutils")
local geometry							= require("hs.geometry")

local Playhead = {}

function Playhead.matches(element)
	return element and element:attributeValue("AXRole") == "AXValueIndicator"
end

-- Finds the playhead (either persistent or skimming) in the specified container.
-- Defaults to persistent.
function Playhead.find(containerUI, skimming)
	local ui = containerUI
	if ui and #ui > 0 then
		-- The playhead is typically one of the last two children
		local persistentPlayhead = ui[#ui-1]
		local skimmingPlayhead = ui[#ui]
		if not Playhead.matches(persistentPlayhead) then
			persistentPlayhead = skimmingPlayhead
			skimmingPlayhead = nil
			if Playhead.matches(skimmingPlayhead) then
				persistentPlayhead = nil
			end
		end
		if skimming then
			return skimmingPlayhead
		else
			return persistentPlayhead
		end
	end
	return nil
end

-- Constructs a new Playhead
--
-- Parameters:
-- * parent 		- The parent object
-- * skimming		- (optional) if `true`, this links to the 'skimming' playhead created under the mouse, if present.
-- * containerFn 	- (optional) a function which returns the container axuielement which contains the playheads.
-- 						If not present, it will use the parent's UI element.
function Playhead:new(parent, skimming, containerFn)
	o = {_parent = parent, _skimming = skimming, containerUI = containerFn}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Playhead:parent()
	return self._parent
end

function Playhead:app()
	return self:parent():app()
end

function Playhead:isPersistent()
	return not self._skimming
end

function Playhead:isSkimming()
	return self._skimming == true
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- BROWSER UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Playhead:UI()
	return axutils.cache(self, "_ui", function()
		local ui = self.containerUI and self:containerUI() or self:parent():UI()
		return Playhead.find(ui, self:isSkimming())
	end,
	Playhead.matches)
end

function Playhead:isShowing()
	return self:UI() ~= nil
end

function Playhead:show()
	local parent = self:parent()
	-- show the parent.
	if parent:show():isShowing() then
		-- ensure the playhead is visible
		if parent.viewFrame then
			local viewFrame = parent:viewFrame()
			local position = self:getPosition()
			if position < viewFrame.x or position > (viewFrame.x + viewFrame.w) then
				-- Need to move the scrollbar
				local timelineFrame = parent:timelineFrame()
				local scrollWidth = timelineFrame.w - viewFrame.w
				local scrollPoint = position - viewFrame.w/2 - timelineFrame.x
				local scrollTarget = scrollPoint/scrollWidth
				parent:scrollHorizontalTo(scrollTarget)
			end
		end
	end
	return self
end

function Playhead:hide()
	return self:parent():hide()
end

function Playhead:getTimecode()
	local ui = self:UI()
	return ui and ui:attributeValue("AXValue")
end

function Playhead:getX()
	local ui = self:UI()
	return ui and ui:position().x
end

function Playhead:getFrame()
	local ui = self:UI()
	return ui and ui:frame()
end

function Playhead:getPosition()
	local frame = self:getFrame()
	return frame and (frame.x + frame.w/2 + 1.0)
end

function Playhead:getCenter()
	local frame = self:getFrame()
	return frame and geometry.rect(frame).center
end

return Playhead