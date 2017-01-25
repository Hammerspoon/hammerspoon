local mouse									= require("hs.mouse")
local geometry								= require("hs.geometry")
local drawing								= require("hs.drawing")
local timer									= require("hs.timer")

local Pucker = {}

Pucker.naturalLength = 20
Pucker.elasticity = Pucker.naturalLength/10

function Pucker:new(colorBoard, aspect, property)
	o = {
		colorBoard = colorBoard,
		aspect = aspect,
		property = property,
		xShift = 0,
		yShift = 0
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Pucker:start()
	-- find the percent and angle UIs
	self.pctUI		= self.colorBoard:aspectPropertyPanelUI(self.aspect, self.property, 'pct')
	self.angleUI	= self.colorBoard:aspectPropertyPanelUI(self.aspect, self.property, 'angle')
	
	-- disable skimming while the pucker is running
	self.menuBar = self.colorBoard:app():menuBar()
	self.skimming = self.menuBar:isChecked("View", "Skimming")
	self.menuBar:uncheckMenu("View", "Skimming")
	
	-- record the origin and draw a marker
	self.origin = mouse.getAbsolutePosition()
	
	self:drawMarker()
	
	-- start the timer
	self.running = true
	Pucker.loop(self)
	return self
end

function Pucker:getBrightness()
	if self.property == "global" then
		return 0.25
	elseif self.property == "shadows" then
		return 0
	elseif self.property == "midtones" then
		return 0.33
	elseif self.property == "highlights" then
		return 0.66
	else
		return 1
	end
end

function Pucker:getArc()
	if self.angleUI then
		return 135, 315
	elseif self.property == "global" then
		return 0, 0
	else
		return 90, 270
	end
end

function Pucker:drawMarker()
	local d = Pucker.naturalLength*2
	local oFrame = geometry.rect(self.origin.x-d/2, self.origin.y-d/2, d, d)
	
	local brightness = self:getBrightness()
	local color = {hue=0, saturation=0, brightness=brightness, alpha=1}

	self.circle = drawing.circle(oFrame)
		:setStrokeColor(color)
		:setFill(true)
		:setStrokeWidth(1)
	
	aStart, aEnd = self:getArc()
	self.arc = drawing.arc(self.origin, d/2, aStart, aEnd)
		:setStrokeColor(color)
		:setFillColor(color)
		:setFill(true)
	
	local rFrame = geometry.rect(self.origin.x-d/4, self.origin.y-d/8, d/2, d/4)
	self.negative = drawing.rectangle(rFrame)
		:setStrokeColor({white=1, alpha=0.75})
		:setStrokeWidth(1)
		:setFillColor({white=0, alpha=1.0 })
		:setFill(true)
end

function Pucker:colorMarker(pct, angle)
	local solidColor = nil
	local fillColor = nil
	
	if angle then
		solidColor = {hue = angle/360, saturation = 1, brightness = 1, alpha = 1}
		fillColor = {hue = angle/360, saturation = 1, brightness = 1, alpha = math.abs(pct/100)}
	else
		brightness = pct >= 0 and 1 or 0
		fillColor = {hue = 0, saturation = 0, brightness = brightness, alpha = math.abs(pct/100)}
	end
	
	if solidColor then
		self.circle:setStrokeColor(solidColor)
		self.arc:setStrokeColor(solidColor)
			:setFillColor(solidColor)
	end
	
	self.circle:setFillColor(fillColor):show()
		
	self.arc:show()
		
	if angle and pct < 0 then
		self.negative:show()
	else
		self.negative:hide()
	end
end

function Pucker:stop()
	self.running = false
end

function Pucker:cleanup()
	self.running = false
	if self.circle then
		self.circle:delete()
		self.circle = nil
	end
	if self.arc then
		self.arc:delete()
		self.arc = nil
	end
	if self.negative then
		self.negative:delete()
		self.negative = nil
	end
	self.pctUI = nil
	self.angleUI = nil
	self.origin = nil
	if self.skimming and self.menuBar then
		self.menuBar:checkMenu("View", "Skimming")
	end
	self.menuBar = nil
	self.colorBoard.pucker = nil
end

function Pucker:accumulate(xShift, yShift)
	if xShift < 1 and xShift > -1 then
		self.xShift = self.xShift + xShift
		if self.xShift > 1 or self.xShift < -1 then
			xShift = self.xShift
			self.xShift = 0
		else
			xShift = 0
		end
	end
	if yShift < 1 and yShift > -1 then
		self.yShift = self.yShift + yShift
		if self.yShift > 1 or self.yShift < -1 then
			yShift = self.yShift
			self.yShift = 0
		else
			yShift = 0
		end
	end
	return xShift, yShift
end

function Pucker.loop(pucker)
	if not pucker.running then
		pucker:cleanup()
		return
	end
	
	local pctUI = pucker.pctUI
	local angleUI = pucker.angleUI
	
	local current = mouse.getAbsolutePosition()
	local xDiff = current.x - pucker.origin.x
	local yDiff = pucker.origin.y - current.y
	
	local xShift = Pucker.tension(xDiff)
	local yShift = Pucker.tension(yDiff)
	
	xShift, yShift = pucker:accumulate(xShift, yShift)
	
	local pctValue = pctUI and tonumber(pctUI:attributeValue("AXValue") or "0") + yShift
	local angleValue = angleUI and (tonumber(angleUI:attributeValue("AXValue") or "0") + xShift + 360) % 360
	pucker:colorMarker(pctValue, angleValue)
	
	if yShift and pctUI then pctUI:setAttributeValue("AXValue", tostring(pctValue)):doConfirm() end
	if xShift and angleUI then angleUI:setAttributeValue("AXValue", tostring(angleValue)):doConfirm() end
	
	timer.doAfter(0.01, function() Pucker.loop(pucker) end)
end

function Pucker.tension(diff)
	local factor = diff < 0 and -1 or 1
	local tension = Pucker.elasticity * (diff*factor-Pucker.naturalLength) / Pucker.naturalLength
	return tension < 0 and 0 or tension * factor
end

return Pucker
