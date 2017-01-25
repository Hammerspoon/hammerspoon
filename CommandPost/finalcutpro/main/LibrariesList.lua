local axutils							= require("hs.finalcutpro.axutils")

local Table								= require("hs.finalcutpro.ui.Table")

local Playhead							= require("hs.finalcutpro.main.Playhead")

local List = {}

function List.matches(element)
	return element and element:attributeValue("AXRole") == "AXSplitGroup"
end

function List:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function List:parent()
	return self._parent
end

function List:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function List:UI()
	return axutils.cache(self, "_ui", function()
		local main = self:parent():mainGroupUI()
		if main then
			for i,child in ipairs(main) do
				if child:attributeValue("AXRole") == "AXGroup" and #child == 1 then
					if List.matches(child[1]) then
						return child[1]
					end
				end
			end
		end
		return nil
	end,
	List.matches)
end

function List:isShowing()
	return self:UI() ~= nil
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- PREVIEW PLAYER
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function List:playerUI()
	return axutils.cache(self, "_player", function()
		local ui = self:UI()
		return ui and axutils.childWithID(ui, "_NS:590")
	end)
end


function List:playhead()
	if not self._playhead then
		self._playhead = Playhead:new(self, false, function()
			return self:playerUI()
		end)
	end
	return self._playhead
end

function List:skimmingPlayhead()
	if not self._skimmingPlayhead then
		self._skimmingPlayhead = Playhead:new(self, true, function()
			return self:playerUI()
		end)
	end
	return self._skimmingPlayhead
end


-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- LIBRARY CONTENT
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function List:contents()
	if not self._content then
		self._content = Table:new(self, function()
			return axutils.childWithID(self:UI(), "_NS:9")
		end)
	end
	return self._content
end

function List:clipsUI()
	local rowsUI = self:contents():rowsUI()
	if rowsUI then
		local level = 0
		-- if the first row has no icon (_NS:11), it's a group
		local firstCell = self:contents():findCellUI(1, "filmlist name col")
		if firstCell and axutils.childWithID(firstCell, "_NS:11") == nil then
			level = 1
		end
		return axutils.childrenWith(rowsUI, "AXDisclosureLevel", level)
	end
	return nil
end

function List:selectedClipsUI()
	return self:contents():selectedRowsUI()
end

function List:showClip(clipUI)
	self:contents():showRow(clipUI)
	return self
end

function List:selectClip(clipUI)
	self:contents():selectRow(clipUI)
	return self
end

function List:selectClipAt(index)
	self:contents():selectRowAt(index)
	return self
end

function List:selectAll(clipsUI)
	self:contents():selectAll(clipsUI)
	return self
end

function List:deselectAll(clipsUI)
	self:contents():deselectAll(clipsUI)
	return self
end

function List:isFocused()
	local player = self:playerUI()
	return self:contents():isFocused() or player and player:focused()
end

return List