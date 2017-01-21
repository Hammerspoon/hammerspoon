local axutils							= require("hs.finalcutpro.axutils")

local tools								= require("hs.fcpxhacks.modules.tools")
local Playhead							= require("hs.finalcutpro.main.Playhead")

local Filmstrip = {}

function Filmstrip.matches(element)
	return element and element:attributeValue("AXIdentifier") == "_NS:33"
end

function Filmstrip:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Filmstrip:parent()
	return self._parent
end

function Filmstrip:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE CONTENT UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Filmstrip:UI()
	return axutils.cache(self, "_ui", function()
		local main = self:parent():mainGroupUI()
		if main then
			for i,child in ipairs(main) do
				if child:attributeValue("AXRole") == "AXGroup" and #child == 1 then
					if Filmstrip.matches(child[1]) then
						return child[1]
					end
				end
			end
		end
		return nil
	end,
	Filmstrip.matches)
end

function Filmstrip:verticalScrollBarUI()
	local ui = self:UI()
	return ui and ui:attributeValue("AXVerticalScrollBar")
end

function Filmstrip:isShowing()
	return self:UI() ~= nil
end

function Filmstrip:contentsUI()
	local ui = self:UI()
	return ui and ui:contents()[1]
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PLAYHEADS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function Filmstrip:playhead()
	if not self._playhead then
		self._playhead = Playhead:new(self, false, function()
			return self:contentsUI()
		end)
	end
	return self._playhead
end

function Filmstrip:skimmingPlayhead()
	if not self._skimmingPlayhead then
		self._skimmingPlayhead = Playhead:new(self, true, function()
			return self:contentsUI()
		end)
	end
	return self._skimmingPlayhead
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- CLIPS
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Filmstrip.sortClips(a, b)
	local aFrame = a:frame()
	local bFrame = b:frame()
	if aFrame.y < bFrame.y then -- a is above b
		return true
	elseif aFrame.y == bFrame.y then
		if aFrame.x < bFrame.x then -- a is left of b
			return true
		elseif aFrame.x == bFrame.x
		   and aFrame.w < bFrame.w then -- a starts with but finishes before b, so b must be multi-line
			return true
		end
	end
	return false -- b is first
end

function Filmstrip:clipsUI()
	local ui = self:contentsUI()
	if ui then
		local clips = axutils.childrenWithRole(ui, "AXGroup")
		if clips then
			table.sort(clips, Filmstrip.sortClips)
			return clips
		end
	end
	return nil
end

function Filmstrip:selectedClipsUI()
	local ui = self:contentsUI()
	if ui then
		local children = ui:selectedChildren()
		local clips = {}
		for i,child in ipairs(children) do
			clips[i] = child
		end
		table.sort(clips, Filmstrip.sortClips)
		return clips
	end
	return nil
end

function Filmstrip:showClip(clipUI)
	local ui = self:UI()
	if ui then
		local vScroll = self:verticalScrollBarUI()
		local vFrame = vScroll:frame()
		local clipFrame = clipUI:frame()

		local top = vFrame.y
		local bottom = vFrame.y + vFrame.h

		local clipTop = clipFrame.y
		local clipBottom = clipFrame.y + clipFrame.h

		if clipTop < top or clipBottom > bottom then
			-- we need to scroll
			local oFrame = self:contentsUI():frame()
			local scrollHeight = oFrame.h - vFrame.h

			local vValue = nil
			if clipTop < top or clipFrame.h > vFrame.h then
				vValue = (clipTop-oFrame.y)/scrollHeight
			else
				vValue = 1.0 - (oFrame.y + oFrame.h - clipBottom)/scrollHeight
			end
			vScroll:setAttributeValue("AXValue", vValue)
		end
	end
	return self
end

function Filmstrip:showClipAt(index)
	local ui = self:clipsUI()
	if ui and #ui >= index then
		self:showClip(ui[index])
	end
	return self
end

function Filmstrip:selectClip(clipUI)
	if axutils.isValid(clipUI) then
		clipUI:parent():setSelectedChildren( { clipUI } )
	end
	return self
end

function Filmstrip:selectClipAt(index)
	local ui = self:clipsUI()
	if ui and #ui >= index then
		self:selectClip(ui[index])
	end
	return self
end

function Filmstrip:selectAll(clipsUI)
	clipsUI = clipsUI or self:clipsUI()
	if clipsUI then
		for i,clip in ipairs(clipsUI) do
			self:selectClip(clip)
		end
	end
	return self
end

function Filmstrip:deselectAll()
	local contents = self:contentsUI()
	if contents then
		contents:setSelectedChildren({})
	end
	return self
end

return Filmstrip