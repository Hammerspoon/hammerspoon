
local USERDATA_TAG = "hs.drawing"

local module = {}
module.color = require(USERDATA_TAG .. ".color")

local canvas       = require"hs.canvas"
local styledtext   = require"hs.styledtext"
local drawingMT    = {}

-- private variables and methods -----------------------------------------

local newDrawing = function(...)
    local result = canvas.new(...)
--     if result then
--         result:_accessibilitySubrole("hammerspoonDrawing")
--     end
    return result
end

-- Public interface ------------------------------------------------------

-- functions/tables from hs.drawing

module._image = function(frame, imageObject)
    local drawingObject = {
        canvas = newDrawing(frame),
    }
    drawingObject.canvas._default.clipToPath = true

    drawingObject.canvas[1] = {
        type          = "image",
        image         = imageObject,
        imageAnimates = true,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.appImage = function(frame, bundleID)
    local image = require("hs.image")
    local tmpImage = image.imageFromAppBundle(bundleID)
    if tmpImage then
        return module._image(frame, tmpImage)
    else
        return nil
    end
end

module.arc = function(centerPoint, radius, startAngle, endAngle)
    local frame = {
        x = centerPoint.x - radius,
        y = centerPoint.y - radius,
        h = radius * 2,
        w = radius * 2
    }
    return module.ellipticalArc(frame, startAngle, endAngle)
end

module.circle = function(frame)
    local drawingObject = {
        canvas = newDrawing(frame),
    }
    drawingObject.canvas[1] = {
        type        = "oval",
        clipToPath  = true,
        strokeWidth = 2,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.ellipticalArc = function(frame, startAngle, endAngle)
    local drawingObject = {
        canvas = newDrawing(frame),
    }
    drawingObject.canvas[1] = {
        type        = "ellipticalArc",
        startAngle  = startAngle,
        endAngle    = endAngle,
        clipToPath  = true,
        arcRadii    = true,
        strokeWidth = 2,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.image = function(frame, imageObject)
    local image = require("hs.image")
    if type(imageObject) == "string" then
        if string.sub(imageObject, 1, 6) == "ASCII:" then
            imageObject = image.imageFromASCII(imageObject)
        else
            imageObject = image.imageFromPath(imageObject)
        end
    end

    if imageObject then
        return module._image(frame, imageObject)
    else
        return nil
    end
end

module.line = function(originPoint, endingPoint)
    local frame = {
        x = math.min(originPoint.x, endingPoint.x),
        y = math.min(originPoint.y, endingPoint.y),
        w = math.max(originPoint.x, endingPoint.x) - math.min(originPoint.x, endingPoint.x),
        h = math.max(originPoint.y, endingPoint.y) - math.min(originPoint.y, endingPoint.y),
    }
    originPoint.x, originPoint.y = originPoint.x - frame.x, originPoint.y - frame.y
    endingPoint.x, endingPoint.y = endingPoint.x - frame.x, endingPoint.y - frame.y
    local drawingObject = {
        canvas = newDrawing(frame),
    }
    drawingObject.canvas[1] = {
        type             = "segments",
        absolutePosition = false,
        absoluteSize     = false,
        coordinates      = { originPoint, endingPoint },
        action           = "stroke",
    }
    return setmetatable(drawingObject, drawingMT)
end

module.rectangle = function(frame)
    local drawingObject = {
        canvas = newDrawing(frame),
    }
    drawingObject.canvas[1] = {
        type       = "rectangle",
        clipToPath = true,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.text = function(frame, message)
    if type(message) == "table" then
        message = styledtext.new(message)
    elseif type(message) ~= "string" and getmetatable(message) ~= hs.getObjectMetatable("hs.styledtext") then
        message = tostring(message)
    end
    local drawingObject = {
        canvas = newDrawing(frame),
    }

    drawingObject.canvas[1] = {
        type             = "text",
        absolutePosition = false,
        absoluteSize     = false,
        text             = message,
    }
    return setmetatable(drawingObject, drawingMT)
end

module.getTextDrawingSize = function(message, textStyle)
    textStyle = textStyle or {}
    local drawingObject = newDrawing({})
    if textStyle.paragraphStyle then
        message = styledtext.new(message, textStyle)
    else
        if textStyle.font      then drawingObject._default.textFont      = textStyle.font end
        if textStyle.size      then drawingObject._default.textSize      = textStyle.size end
        if textStyle.color     then drawingObject._default.textColor     = textStyle.color end
        if textStyle.alignment then drawingObject._default.textAlignment = textStyle.alignment end
        if textStyle.lineBreak then drawingObject._default.textLineBreak = textStyle.lineBreak end
    end
    local frameSize = drawingObject:minimumTextSize(message)
    drawingObject:delete()
    return frameSize
end

module.defaultTextStyle     = canvas.defaultTextStyle
module.disableScreenUpdates = canvas.disableScreenUpdates
module.enableScreenUpdates  = canvas.enableScreenUpdates
module.fontNames            = styledtext.fontNames
module.fontNamesWithTraits  = styledtext.fontNamesWithTraits
module.fontTraits           = styledtext.fontTraits
module.windowBehaviors      = canvas.windowBehaviors
module.windowLevels         = canvas.windowLevels

-- methods from hs.drawing

drawingMT.clippingRectangle = function(self, ...)
    local args = table.pack(...)
    local frame = { -- we need a copy, since we're going to modify it
        x = args[1].x,
        y = args[1].y,
        w = args[1].w,
        h = args[1].h,
    }
    if args.n ~= 1 then
        error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
    elseif type(frame) ~= "table" and type(frame) ~= "nil" then
        error(string.format("ERROR: incorrect type '%s' for argument 2 (expected table)", type(args[1])), 2)
    else
        if frame then
            local parentFrame = self.canvas:frame()
            frame.x, frame.y = frame.x - parentFrame.x, frame.y - parentFrame.y
            if self.canvas[1].action ~= "clip" then
                self.canvas:insertElement({
                    type = "rectangle",
                    action = "clip",
                    frame = frame
                }, 1)
            elseif self.canvas[1].action == "clip" then
                self.canvas[1].frame = frame
            end
        elseif self.canvas[1].action == "clip" then
            self.canvas:removeElement(1)
        end
        return self
    end
end

drawingMT.delete = function(self)
    self.canvas = self.canvas:delete()
    setmetatable(self, nil)
end

drawingMT.getStyledText = function(self)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        local text = self.canvas[#self.canvas].text
        if type(text) == "string" then
            return styledtext.new(text)
        else
            return text
        end
    else
        error(string.format("calling 'getStyledText' on bad self (not an %s.text() object)", USERDATA_TAG), 2)
    end
end

drawingMT.setStyledText = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        local text = args[1]
        if type(text) ~= "userdata" and type(text) ~= "table" then
        -- we don't inherit from the textContainer like hs.drawing.text does
            text = styledtext.new(text, {
                font = {
                    name = self.canvas[#self.canvas].textFont,
                    size = self.canvas[#self.canvas].textSize,
                },
                color = self.canvas[#self.canvas].textColor,
                paragraphStyle = {
                    alignment = self.canvas[#self.canvas].textAlignment,
                    lineBreak = self.canvas[#self.canvas].textLineBreak,
                },
            })
        end
        self.canvas[#self.canvas].text = text
        self.canvas[#self.canvas].frame.y = 0
    else
        error(string.format("calling 'getStyledText' on bad self (not an %s.text() object)", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.setArcAngles = function(self, ...)
    local args = table.pack(...)
    if ({ ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        if args.n ~= 2 then
            error(string.format("ERROR: incorrect number of arguments. Expected 3, got %d", args.n), 2)
        end
        self.canvas[#self.canvas].startAngle = args[1]
        self.canvas[#self.canvas].endAngle   = args[2]
    else
        error(string.format("%s:setArcAngles() can only be called on %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setClickCallback = function(self, ...)
    local args = table.pack(...)
    local mouseUpFn, mouseDnFn = args[1], args[2]
    if (type(mouseUpFn) ~= "function" and type(mouseUpFn) ~= "nil") or args.n == 0 then
        error(string.format("%s:setClickCallback() mouseUp argument must be a function or nil", USERDATA_TAG), 2)
    end
    if type(mouseDnFn) ~= "function" and type(mouseDnFn) ~= "nil" then
        error(string.format("%s:setClickCallback() mouseDown argument must be a function or nil, or entirely absent", USERDATA_TAG), 2)
    end

    self.canvas:canvasMouseEvents(mouseDnFn and true or false, mouseUpFn and true or false)
    if mouseDnFn or mouseUpFn then
        self.canvas:mouseCallback(function(_, m)
            if     m == "mouseUp"   and mouseUpFn then mouseUpFn()
            elseif m == "mouseDown" and mouseDnFn then mouseDnFn()
            end
        end)
    else
        self.canvas:mouseCallback(nil)
    end
    return self
end

drawingMT.setFill = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        local currentAction = self.canvas[#self.canvas].action
        if args[1] then
            self.canvas[#self.canvas].fillGradient = "none"
            if currentAction == "stroke" then
                self.canvas[#self.canvas].action = "strokeAndFill"
            elseif currentAction == "skip" then
                self.canvas[#self.canvas].action = "fill"
            end
            if self.canvas[#self.canvas].type == "ellipticalArc" then
                self.canvas[#self.canvas].arcRadii = true
            end
        else
            if currentAction == "strokeAndFill" then
                self.canvas[#self.canvas].action = "stroke"
            elseif currentAction == "fill" then
                self.canvas[#self.canvas].action = "skip"
            end
            if self.canvas[#self.canvas].type == "ellipticalArc" then
                self.canvas[#self.canvas].arcRadii = false
            end
        end
    else
        error(string.format("%s:setFill() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setFillColor = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].fillColor = args[1]
    else
        error(string.format("%s:setFillColor() can only be called on %s.rectangle(), %s.circle(), or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setFillGradient = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].fillGradientColors = { args[1], args[2] }
        self.canvas[#self.canvas].fillGradientAngle  = args[3]
        self.canvas[#self.canvas].fillGradient       = "linear"
    else
        error(string.format("%s:setFillGradient() can only be called on %s.rectangle(), %s.circle(), or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setImage = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].image = args[1]
    else
        error(string.format("%s:setImage() can only be called on %s.image() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setImageFromASCII = function(self, ...)
    local args = table.pack(...)
    local imageObject = args[1]
    local image = require("hs.image")
    if type(imageObject) == "string" then
        if string.sub(imageObject, 1, 6) == "ASCII:" then
            imageObject = image.imageFromASCII(imageObject)
        else
            imageObject = image.imageFromPath(imageObject)
        end
    end
    return self:setImage(imageObject)
end
drawingMT.setImageFromPath = drawingMT.setImageFromASCII
drawingMT.setImagePath     = drawingMT.setImagePath

drawingMT.setRoundedRectRadii = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].roundedRectRadii = { xRadius = args[1], yRadius = args[2] }
    else
        error(string.format("%s:setRoundedRectRadii() can only be called on %s.rectangle() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStroke = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        local currentAction = self.canvas[#self.canvas].action
        if args[1] then
            if currentAction == "fill" then
                self.canvas[#self.canvas].action = "strokeAndFill"
            elseif currentAction == "skip" then
                self.canvas[#self.canvas].action = "stroke"
            end
        else
            if currentAction == "strokeAndFill" then
                self.canvas[#self.canvas].action = "fill"
            elseif currentAction == "stroke" then
                self.canvas[#self.canvas].action = "skip"
            end
        end
    else
        error(string.format("%s:setStroke() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStrokeColor = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, oval = 1, ellipticalArc = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].strokeColor = args[1]
    else
        error(string.format("%s:setStrokeColor() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setStrokeWidth = function(self, ...)
    local args = table.pack(...)
    if ({ rectangle = 1, segments = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].strokeWidth = args[1]
    elseif ({ oval = 1, ellipticalArc = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].strokeWidth = args[1] * 2
    else
        error(string.format("%s:setStrokeWidth() can only be called on %s.rectangle(), %s.circle(), %s.line() or %s.arc() objects, not: %s", USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setText = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].text = tostring(args[1])
    else
        hs.luaSkinLog.ef("%s:setText() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type)
    end
    return self
end

drawingMT.setTextColor = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textColor = args[1]
    else
        error(string.format("%s:setTextColor() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextFont = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textFont = args[1]
    else
        error(string.format("%s:setTextFont() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextSize = function(self, ...)
    local args = table.pack(...)
    if ({ text = 1 })[self.canvas[#self.canvas].type] then
        self.canvas[#self.canvas].textSize = args[1]
    else
        error(string.format("%s:setTextSize() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
    end
    return self
end

drawingMT.setTextStyle = function(self, ...)
    local args = table.pack(...)
    if type(args[1]) ~= "table" and type(args[1]) ~= "nil" then
        error(string.format("invalid textStyle type specified: %s", type(args[1])), 2)
    else
        if ({ text = 1 })[self.canvas[#self.canvas].type] then
            local style = args[1]
            if (style) then
                if style.font      then self.canvas[#self.canvas].textFont      = style.font end
                if style.size      then self.canvas[#self.canvas].textSize      = style.size end
                if style.color     then self.canvas[#self.canvas].textColor     = style.color end
                if style.alignment then self.canvas[#self.canvas].textAlignment = style.alignment end
                if style.lineBreak then self.canvas[#self.canvas].textLineBreak = style.lineBreak end
            else
                self.canvas[#self.canvas].textFont      = nil
                self.canvas[#self.canvas].textSize      = nil
                self.canvas[#self.canvas].textColor     = nil
                self.canvas[#self.canvas].textAlignment = nil
                self.canvas[#self.canvas].textLineBreak = nil
            end
        else
            error(string.format("%s:setTextStyle() can only be called on %s.text() objects, not: %s", USERDATA_TAG, USERDATA_TAG, self.canvas[#self.canvas].type), 2)
        end
    end
    return self
end

drawingMT.imageAlignment = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        if args.n == 0 then
            return self.canvas[#self.canvas].imageAlignment
        elseif args.n == 1 then
            self.canvas[#self.canvas].imageAlignment = args[1]
        else
            error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
        end
    else
        error(string.format("%s:imageAlignment() called on an hs.drawing object that isn't an image object", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.imageAnimates = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        if args.n == 0 then
            return self.canvas[#self.canvas].imageAnimates
        elseif args.n == 1 then
            self.canvas[#self.canvas].imageAnimates = args[1]
        else
            error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
        end
    else
        error(string.format("%s:imageAnimates() called on an hs.drawing object that isn't an image object", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.imageFrame = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        if args.n == 0 then
            return self._imageFrame or "none"
        elseif args.n == 1 then
            local style = args[1]
            if ({ none = 1, photo = 1, bezel = 1, groove = 1, button = 1 })[style] then
                local frameStart = (self.canvas[1].action == "clip") and 2 or 1
                local frameEnd   = #self.canvas - 1
                while frameEnd >= frameStart do
                    self.canvas:removeElement(frameEnd)
                    frameEnd = frameEnd - 1
                end
                self._imageFrame = nil
                local padding = 0

                local blackColor = module.color.colorsFor("System").controlDarkShadowColor
                local darkColor  = module.color.colorsFor("System").controlShadowColor
                local whiteColor = module.color.colorsFor("System").controlHighlightColor
                local size = self.canvas:size()

                if     style == "photo" then
                    self.canvas:insertElement({
                        type = "rectangle",
                        action = "fill",
                        fillColor = whiteColor,
                    }, frameStart)
                    self.canvas:insertElement({
                        type = "segments",
                        action = "stroke",
                        strokeWidth = 2,
                        closed = false,
                        strokeColor = blackColor,
                        coordinates = {
                            { x = 0, y = size.h - 1 },
                            { x = 0, y = 0 },
                            { x = size.w - 1, y = 0 }
                        }
                    }, frameStart + 1)
                    self.canvas:insertElement({
                        type = "segments",
                        action = "stroke",
                        strokeWidth = 2,
                        closed = false,
                        strokeColor = darkColor,
                        coordinates = {
                            { x = size.w, y = 2 },
                            { x = size.w, y = size.h },
                            { x = 2, y = size.h }
                        }
                    }, frameStart + 2)
                    self.canvas:insertElement({
                        type = "segments",
                        action = "stroke",
                        strokeWidth = 2,
                        closed = false,
                        strokeColor = darkColor,
                        coordinates = {
                            { x = size.w - 1, y = 1 },
                            { x = size.w - 1, y = size.h - 1 },
                            { x = 1, y = size.h - 1 }
                        }
                    }, frameStart + 3)
                    self._imageFrame = "photo"
                    padding = 2
                elseif style == "bezel" then
                    self.canvas:insertElement({
                        type = "rectangle",
                        strokeColor = whiteColor,
                        strokeWidth = 4,
                        action = "stroke",
                        roundedRectRadii = {
                            xRadius = 5,
                            yRadius = 5,
                        }
                    }, frameStart)
                    self._imageFrame = "bezel"
                    padding = 7
                elseif style == "groove" then
                    self.canvas:insertElement({
                        type = "rectangle",
                        action = "fill",
                        fillColor = darkColor,
                    }, frameStart)
                    self.canvas:insertElement({
                        type = "rectangle",
                        action = "stroke",
                        strokeColor = whiteColor,
                        strokeWidth = 2,
                        padding = 1,
                    }, frameStart + 1)
                    self._imageFrame = "groove"
                    padding = 3
                elseif style == "button" then
                    self.canvas:insertElement({
                        type = "rectangle",
                        action = "fill",
                        fillColor = darkColor,
                    }, frameStart)
                    self.canvas:insertElement({
                        type = "segments",
                        action = "stroke",
                        strokeWidth = 2,
                        closed = false,
                        strokeColor = whiteColor,
                        coordinates = {
                            { x = 0, y = size.h },
                            { x = 0, y = 0 },
                            { x = size.w - 1, y = 0 }
                        }
                    }, frameStart + 1)
                    self.canvas:insertElement({
                        type = "segments",
                        action = "stroke",
                        strokeWidth = 2,
                        closed = false,
                        strokeColor = blackColor,
                        coordinates = {
                            { x = size.w, y = 0 },
                            { x = size.w, y = size.h },
                            { x = 1, y = size.h }
                        }
                    }, frameStart + 2)
                    self._imageFrame = "button"
                    padding = 2
                end

                self.canvas[#self.canvas].padding = padding
            else
                error(string.format("%s:frameStyle unrecognized frame specified", USERDATA_TAG), 2)
            end
        else
            error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
        end
    else
        error(string.format("%s:imageFrame() called on an hs.drawing object that isn't an image object", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.imageScaling = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        if args.n == 0 then
            return self.canvas[#self.canvas].imageScaling
        elseif args.n == 1 then
            self.canvas[#self.canvas].imageScaling = args[1]
        else
            error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
        end
    else
        error(string.format("%s:imageScaling() called on an hs.drawing object that isn't an image object", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.rotateImage = function(self, ...)
    local args = table.pack(...)
    if ({ image = 1 })[self.canvas[#self.canvas].type] then
        if args.n == 1 then
            local size = self.canvas:size()
            self.canvas[#self.canvas].transformation = canvas.matrix.translate(size.w / 2, size.h / 2)
                                                                    :rotate(args[1])
                                                                    :translate(size.w / -2, size.h / -2)
        else
            error(string.format("ERROR: incorrect number of arguments. Expected 2, got %d", args.n), 2)
        end
    else
        error(string.format("%s:rotateImage() called on an hs.drawing object that isn't an image object", USERDATA_TAG), 2)
    end
    return self
end

drawingMT.orderAbove = function(self, other)
    self.canvas:orderAbove(other and other.canvas or nil)
    return self
end

drawingMT.orderBelow = function(self, other)
    self.canvas:orderBelow(other and other.canvas or nil)
    return self
end

drawingMT.setFrame = function(self, ...)
    drawingMT.setSize(self, ...)
    drawingMT.setTopLeft(self, ...)
    return self
end

drawingMT.alpha                   = function(self) return self.canvas:alpha() end
drawingMT.setAlpha                = function(self, ...) self.canvas:alpha(...) ; return self end
drawingMT.behavior                = function(self) return self.canvas:behavior() end
drawingMT.setBehavior             = function(self, ...) self.canvas:behavior(...) ; return self end
drawingMT.behaviorAsLabels        = function(self) return self.canvas:behaviorAsLabels() end
drawingMT.setBehaviorByLabels     = function(self, ...) self.canvas:behaviorAsLabels(...) ; return self end
drawingMT.bringToFront            = function(self, ...) self.canvas:bringToFront(...) ; return self end
drawingMT.clickCallbackActivating = function(self, ...) self.canvas:clickActivating(...) ; return self end
drawingMT.frame                   = function(self) return self.canvas:frame() end
drawingMT.hide                    = function(self, ...) self.canvas:hide(...) ; return self end
drawingMT.sendToBack              = function(self, ...) self.canvas:sendToBack(...) ; return self end
drawingMT.setLevel                = function(self, ...) self.canvas:level(...) ; return self end
drawingMT.setSize                 = function(self, ...) self.canvas:size(...) ; return self end
drawingMT.setTopLeft              = function(self, ...) self.canvas:topLeft(...) ; return self end
drawingMT.show                    = function(self, ...) self.canvas:show(...) ; return self end
drawingMT.wantsLayer              = function(self, ...) self.canvas:wantsLayer(...) ; return self end

drawingMT.__index    = drawingMT
drawingMT.__type     = USERDATA_TAG
drawingMT.__tostring = function(_)
    return USERDATA_TAG .. ": " .. _.canvas[#_.canvas].type
end

-- assign to the registry in case we ever need to access the metatable from the C side

debug.getregistry()[USERDATA_TAG] = drawingMT

-- Return Module Object --------------------------------------------------

return module
