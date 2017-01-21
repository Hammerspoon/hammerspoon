local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")

local _bench							= require("hs.bench")

local Inspector = {}

function Inspector.matches(element)
	return axutils.childWith(element, "AXIdentifier", "_NS:112") ~= nil -- is inspecting
		or axutils.childWith(element, "AXIdentifier", "_NS:53") ~= nil 	-- nothing to inspect
end

function Inspector:new(parent)
	o = {_parent = parent}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Inspector:parent()
	return self._parent
end

function Inspector:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- Inspector UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function Inspector:UI()
	return axutils.cache(self, "_ui", 
	function()
		local parent = self:parent()
		local ui = parent:rightGroupUI()
		if ui then
			-- it's in the right panel (full-height)
			if Inspector.matches(ui) then
				return ui
			end
		else
			-- it's in the top-left panel (half-height)
			local top = parent:topGroupUI()
			for i,child in ipairs(top) do
				if Inspector.matches(child) then
					return child
				end
			end
		end
		return nil
	end,
	Inspector.matches)
end

function Inspector:isShowing()
	return self:app():menuBar():isChecked("Window", "Show in Workspace", "Inspector")
end

function Inspector:show()
	local parent = self:parent()
	-- show the parent.
	if parent:show() then
		local menuBar = self:app():menuBar()
		-- Enable it in the primary
		menuBar:checkMenu("Window", "Show in Workspace", "Inspector")
	end
	return self
end


function Inspector:hide()
	local menuBar = self:app():menuBar()
	-- Uncheck it from the primary workspace
	menuBar:uncheckMenu("Window", "Show in Workspace", "Inspector")
	return self
end

return Inspector