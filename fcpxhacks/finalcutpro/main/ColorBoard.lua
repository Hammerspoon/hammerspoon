local log								= require("hs.logger").new("timline")
local inspect							= require("hs.inspect")

local just								= require("hs.just")
local axutils							= require("hs.finalcutpro.axutils")
local tools								= require("hs.fcpxhacks.modules.tools")
local geometry							= require("hs.geometry")

local Pucker							= require("hs.finalcutpro.main.ColorPucker")

local ColorBoard = {}

ColorBoard.aspect						= {}
ColorBoard.aspect.color					= {
	id 									= 1, 
	reset 								= "_NS:288", 
	global 								= { puck = "_NS:278", pct = "_NS:70", angle = "_NS:98"}, 
	shadows 							= { puck = "_NS:273", pct = "_NS:77", angle = "_NS:104"}, 
	midtones 							= { puck = "_NS:268", pct = "_NS:84", angle = "_NS:110"}, 
	highlights 							= { puck = "_NS:258", pct = "_NS:91", angle = "_NS:116"}
}
ColorBoard.aspect.saturation			= {
	id 									= 2,
	reset 								= "_NS:538",
	global 								= { puck = "_NS:529", pct = "_NS:42"},
	shadows 							= { puck = "_NS:524", pct = "_NS:49"},
	midtones 							= { puck = "_NS:519", pct = "_NS:56"},
	highlights 							= { puck = "_NS:514", pct = "_NS:63"}
}
ColorBoard.aspect.exposure				= {
	id									= 3,
	reset								= "_NS:412",
	global								= { puck = "_NS:403", pct = "_NS:9"},
	shadows 							= { puck = "_NS:398", pct = "_NS:21"},
	midtones							= { puck = "_NS:393", pct = "_NS:28"},
	highlights							= { puck = "_NS:388", pct = "_NS:35"}
}
ColorBoard.currentAspect = "*"

function ColorBoard.isColorBoard(element)
	for i,child in ipairs(element) do
		if axutils.childWith(child, "AXIdentifier", "_NS:180") then
			return true
		end
	end
	return false
end

function ColorBoard:new(parent)
	o = {
		_parent = parent,
		_child = {}
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ColorBoard:parent()
	return self._parent
end

function ColorBoard:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- ColorBoard UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function ColorBoard:UI()
	return axutils.cache(self, "_ui", 
	function()
		local parent = self:parent()
		local ui = parent:rightGroupUI()
		if ui then
			-- it's in the right panel (full-height)
			if ColorBoard.isColorBoard(ui) then
				return ui
			end
		else
			-- it's in the top-left panel (half-height)
			local top = parent:topGroupUI()
			for i,child in ipairs(top) do
				if ColorBoard.isColorBoard(child) then
					return child
				end
			end
		end
		return nil
	end,
	function(element) return ColorBoard:isColorBoard(element) end)
end

function ColorBoard:_findUI()
end

function ColorBoard:isShowing()
	local ui = self:UI()
	return ui ~= nil and ui:attributeValue("AXSize").w > 0
end

function ColorBoard:show()
	if not self:isShowing() then
		self:app():menuBar():selectMenu("Window", "Go To", "Color Board")
	end
	return self
end


function ColorBoard:hide()
	local ui = self:showInspectorUI()
	if ui then ui:doPress() end
	return self
end


function ColorBoard:childUI(id)
	return axutils.cache(self._child, id, function()
		local ui = self:UI()
		return ui and axutils.childWith(ui, "AXIdentifier", id)
	end)
end

function ColorBoard:topToolbarUI()
	return axutils.cache(self, "_topToolbar", function()
		local ui = self:UI()
		if ui then
			for i,child in ipairs(ui) do
				if axutils.childWith(child, "AXIdentifier", "_NS:180") then
					return child
				end
			end
		end
		return nil
	end)
end

function ColorBoard:showInspectorUI()
	return axutils.cache(self, "_showInspector", function()
		local ui = self:topToolbarUI()
		if ui then
			return axutils.childWith(ui, "AXIdentifier", "_NS:180")
		end
		return nil
	end)
end

function ColorBoard:isActive()
	local ui = self:colorSatExpUI()
	return ui ~= nil and axutils.childWith(ui:parent(), "AXIdentifier", "_NS:128")
end
		

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- Color Correction Panels
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function ColorBoard:colorSatExpUI()
	return axutils.cache(self, "_colorSatExp", function()
		local ui = self:UI()
		return ui and axutils.childWith(ui, "AXIdentifier", "_NS:128")
	end)
end

function ColorBoard:getAspect(aspect, property)
	local panel = nil
	if type(aspect) == "string" then
		if aspect == ColorBoard.currentAspect then
			-- return the currently-visible aspect
			local ui = self:colorSatExpUI()
			if ui then
				for k,value in pairs(ColorBoard.aspect) do
					if ui[value.id]:value() == 1 then
						panel = value
					end
				end
			end
		else
			panel = ColorBoard.aspect[aspect]
		end
	else
		panel = name
	end
	if panel and property then
		return panel[property]
	end
	return panel
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- Panel Controls
---
--- These methds are passed the aspect (color, saturation, exposure)
--- and sometimes a property (id, global, shadows, midtones, highlights)
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function ColorBoard:showPanel(aspect)
	self:show()
	aspect = self:getAspect(aspect)
	local ui = self:colorSatExpUI()
	if aspect and ui and ui[aspect.id]:value() == 0 then
		ui[aspect.id]:doPress()
	end
	return self
end

function ColorBoard:reset(aspect)
	aspect = self:getAspect(aspect)
	self:showPanel(aspect)
	local ui = self:UI()
	if ui then
		local reset = axutils.childWith(ui, "AXIdentifier", aspect.reset)
		if reset then
			reset:doPress()
		end
	end
	return self
end

function ColorBoard:puckUI(aspect, property)
	local details = self:getAspect(aspect, property)
	return self:childUI(details.puck)
end

function ColorBoard:selectPuck(aspect, property)
	self:showPanel(aspect)
	local puckUI = self:puckUI(aspect, property)
	if puckUI then
		local f = puckUI:frame()
		local centre = geometry(f.x + f.w/2, f.y + f.h/2)
		tools.ninjaMouseClick(centre)
	end
	return self
end


--- Ensures that the specified aspect/property (eg 'color/global')
--- 'edit' panel is visible and returns the specified value type UI
--- (eg. 'pct' or 'angle')
function ColorBoard:aspectPropertyPanelUI(aspect, property, type)
	if not self:isShowing() then
		return nil
	end
	self:showPanel(aspect)
	local details = self:getAspect(aspect, property)
	if not details[type] then
		return nil
	end
	local ui = self:childUI(details[type])
	if not ui then -- short inspector panels can hide some details panels
		self:selectPuck(aspect, property)
		-- try again
		ui = self:childUI(details[type])
	end
	return ui
end

function ColorBoard:applyPercentage(aspect, property, value)
	local pctUI = self:aspectPropertyPanelUI(aspect, property, 'pct')
	if pctUI then
		pctUI:setAttributeValue("AXValue", tostring(value))
		pctUI:doConfirm()
	end
	return self
end

function ColorBoard:shiftPercentage(aspect, property, shift)
	local ui = self:aspectPropertyPanelUI(aspect, property, 'pct')
	if ui then
		local value = tonumber(ui:attributeValue("AXValue") or "0")
		ui:setAttributeValue("AXValue", tostring(value + shift))
		ui:doConfirm()
	end
	return self	
end

function ColorBoard:getPercentage(aspect, property)
	local pctUI = self:aspectPropertyPanelUI(aspect, property, 'pct')
	if pctUI then
		return tonumber(pctUI:attributeValue("AXValue"))
	end
	return nil
end

function ColorBoard:applyAngle(aspect, property, value)
	local angleUI = self:aspectPropertyPanelUI(aspect, property, 'angle')
	if angleUI then
		angleUI:setAttributeValue("AXValue", tostring(value))
		angleUI:doConfirm()
	end
	return self
end

function ColorBoard:shiftAngle(aspect, property, shift)
	local ui = self:aspectPropertyPanelUI(aspect, property, 'angle')
	if ui then
		local value = tonumber(ui:attributeValue("AXValue") or "0")
		-- loop around between 0 and 360 degrees
		value = (value + shift + 360) % 360
		ui:setAttributeValue("AXValue", tostring(value))
		ui:doConfirm()
	end
	return self	
end

function ColorBoard:getAngle(aspect, property, value)
	local angleUI = self:aspectPropertyPanelUI(aspect, property, 'angle')
	if angleUI then
		local value = angleUI:getAttributeValue("AXValue")
		if value ~= nil then return tonumber(value) end
	end
	return nil
end

function ColorBoard:startPucker(aspect, property)
	if self.pucker then
		self.pucker:cleanup()
		self.pucker = nil
	end
	self.pucker = Pucker:new(self, aspect, property):start()
	return self.pucker
end

return ColorBoard