--- === hs.tangent ===
---
--- **Tangent Control Surface Extension**
---
--- **API Version:** TUBE Version 3.2 - TIPC Rev 4 (22nd February 2017)
---
--- This plugin allows Hammerspoon to communicate with Tangent's range of panels, such as their Element, Virtual Element Apps, Wave, Ripple and any future panels.
---
--- The Tangent Unified Bridge Engine (TUBE) is made up of two software elements, the Mapper and the Hub. The Hub communicates with your application via the
--- TUBE Inter Process Communications (TIPC). TIPC is a standardised protocol to allow any application that supports it to communicate with any current and
--- future panels produced by Tangent via the TUBE Hub.
---
--- You can download the Tangent Developer Support Pack & Tangent Hub Installer for Mac [here](http://www.tangentwave.co.uk/developer-support/).
---
--- This extension was thrown together by [Chris Hocking](http://latenitefilms.com) for [CommandPost](http://commandpost.io).

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------

local log                                       = require("hs.logger").new("tangent")
local fs                                        = require("hs.fs")
local socket                                    = require("hs.socket")
local timer                                     = require("hs.timer")

local unpack, pack 								= string.unpack, string.pack

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------

local mod = {}

--------------------------------------------------------------------------------
-- MODULE CONSTANTS:
--------------------------------------------------------------------------------

--- hs.tangent.HUB_MESSAGE -> table
--- Constant
--- Definitions for IPC Commands from the HUB to Hammerspoon.
mod.HUB_MESSAGE = {
    ["INITIATE_COMMS"]                          = 0x01,
    ["PARAMETER_CHANGE"]                        = 0x02,
    ["PARAMETER_RESET"]                         = 0x03,
    ["PARAMETER_VALUE_REQUEST"]                 = 0x04,
    ["MENU_CHANGE"]                             = 0x05,
    ["MENU_RESET"]                              = 0x06,
    ["MENU_STRING_REQUEST"]                     = 0x07,
    ["ACTION_ON"]                               = 0x08,
    ["MODE_CHANGE"]                             = 0x09,
    ["TRANSPORT"]                               = 0x0A,
    ["ACTION_OFF"]                              = 0x0B,
    ["UNMANAGED_PANEL_CAPABILITIES"]            = 0x30,
    ["UNMANAGED_BUTTON_DOWN"]                   = 0x31,
    ["UNMANAGED_BUTTON_UP"]                     = 0x32,
    ["UNMANAGED_ENCODER_CHANGE"]                = 0x33,
    ["UNMANAGED_DISPLAY_REFRESH"]               = 0x34,
    ["PANEL_CONNECTION_STATE"]                  = 0x35,
}

--- hs.tangent.APP_MESSAGE -> table
--- Constant
--- Definitions for IPC Commands from Hammerspoon to the HUB.
mod.APP_MESSAGE = {
    ["APPLICATION_DEFINITION"]                  = 0x81,
    ["PARAMETER_VALUE"]                         = 0x82,
    ["MENU_STRING"]                             = 0x83,
    ["ALL_CHANGE"]                              = 0x84,
    ["MODE_VALUE"]                              = 0x85,
    ["DISPLAY_TEXT"]                            = 0x86,
    ["UNMANAGED_PANEL_CAPABILITIES_REQUEST"]    = 0xA0,
    ["UNMANAGED_DISPLAY_WRITE"]                 = 0xA1,
    ["RENAME_CONTROL"]                          = 0xA2,
    ["HIGHLIGHT_CONTROL"]                       = 0xA3,
    ["INDICATE_CONTROL"]                        = 0xA4,
    ["REQUEST_PANEL_CONNECTION_STATES"]         = 0xA5,
}

--- hs.tangent.PANEL_TYPE -> table
--- Constant
--- Tangent Panel Types.
mod.PANEL_TYPE = {
    ["CP200-BK"]                                = 0x03,
    ["CP200-K"]                                 = 0x04,
    ["CP200-TS"]                                = 0x05,
    ["CP200-S"]                                 = 0x09,
    ["Wave"]                                    = 0x0A,
    ["Element-Tk"]                              = 0x0C,
    ["Element-Mf"]                              = 0x0D,
    ["Element-Kb"]                              = 0x0E,
    ["Element-Bt"]                              = 0x0F,
    ["Ripple"]                                  = 0x11,
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS:
--------------------------------------------------------------------------------

-- doesDirectoryExist(path) -> string
-- Function
-- Returns whether or not a directory exists.
--
-- Parameters:
--  * path - the path of the directory you want to check as a string.
--
-- Returns:
--  * `true` if the directory exists otherwise `false`
local function doesDirectoryExist(path)
    if path then
        local attr = fs.attributes(path)
        return attr and attr.mode == 'directory'
    else
        return false
    end
end

-- doesFileExist(path) -> boolean
-- Function
-- Returns whether or not a file exists.
--
-- Parameters:
--  * path - Path to the file
--
-- Returns:
--  * `true` if the file exists otherwise `false`
local function doesFileExist(path)
    if path == nil then return nil end
    local attr = fs.attributes(path)
    if type(attr) == "table" then
        return true
    else
        return false
    end
end

-- getPanelType(id) -> string
-- Function
-- Returns the Panel Type based on an ID
--
-- Parameters:
--  * id - ID of the Panel Type you want to return
--
-- Returns:
--  * Panel Type as string
local function getPanelType(id)
    for i,v in pairs(mod.PANEL_TYPE) do
        if id == v then
            return i
        end
    end
end

-- byteStringToNumber(str, offset, numberOfBytes) -> number
-- Function
-- Translates a Byte String into a Number
--
-- Parameters:
--  * str - The string you want to translate
--  * offset - An offset
--  * numberOfBytes - Number of bytes
--  * signed - `true` if it's a signed integer otherwise `false`
--
-- Returns:
--  * A number value
local function byteStringToNumber(str, offset, numberOfBytes, signed)
    local format = ">I" .. tostring(numberOfBytes)
    if signed then
        format = ">i" .. tostring(numberOfBytes)
    end
  return unpack(format, str:sub(offset, offset + numberOfBytes - 1))
end

-- byteStringToFloat(str, offset, numberOfBytes) -> number
-- Function
-- Translates a Byte String into a Float Number
--
-- Parameters:
--  * str - The string you want to translate
--  * offset - An offset
--  * numberOfBytes - Number of bytes
--
-- Returns:
--  * A number value
local function byteStringToFloat(str, offset, numberOfBytes)
    return unpack(">f", str:sub(offset, offset + numberOfBytes - 1))
end

-- byteStringToBoolean(str, offset, numberOfBytes) -> boolean
-- Function
-- Translates a Byte String into a Boolean
--
-- Parameters:
--  * str - The string you want to translate
--  * offset - An offset
--  * numberOfBytes - Number of bytes
--
-- Returns:
--  * A boolean value
local function byteStringToBoolean(str, offset, numberOfBytes)
  local x = byteStringToNumber(str, offset, numberOfBytes)
  return x == 1 or false
end

-- numberToByteString(n) -> string
-- Function
-- Translates a number into a byte string.
--
-- Parameters:
--  * n - The number you want to translate
--
-- Returns:
--  * A string
local function numberToByteString(n)
    if not type(n) == "number" then
        log.ef("numberToByteString() was fed something other than a number")
        return nil
    end
    return pack(">I4", n)
end

-- floatToByteString(n) -> string
-- Function
-- Translates a float number into a byte string.
--
-- Parameters:
--  * n - The number you want to translate
--
-- Returns:
--  * A string
local function floatToByteString(n)
    if not type(n) == "number" then
        log.ef("floatToByteString() was fed something other than a number")
        return nil
    end
    return pack(">f", n)
end

-- booleanToByteString(value) -> string
-- Function
-- Translates a boolean into a byte string.
--
-- Parameters:
--  * value - The boolean you want to translate
--
-- Returns:
--  * A string
local function booleanToByteString(value)
    if value == true then
        return numberToByteString(1)
    else
        return numberToByteString(0)
    end
end

-- processHubCommand(data) -> none
-- Function
-- Processes a single HUB Command.
--
-- Parameters:
--  * data - The raw data from the socket.
--
-- Returns:
--  * None
local function processHubCommand(data)
    local id = byteStringToNumber(data, 1, 4)
    if id == mod.HUB_MESSAGE["INITIATE_COMMS"] then
        --------------------------------------------------------------------------------
        -- InitiateComms (0x01)
        --  * Initiates communication between the Hub and the application.
        --  * Communicates the quantity, type and IDs of the panels which are
        --    configured to be connected in the panel-list.xml file. Note that this is
        --    not the same as the panels which are actually connected – just those
        --    which are expected to be connected.
        --  * The length is dictated by the number of panels connected as the details
        --    of each panel occupies 5 bytes.
        --  * On receipt the application should respond with the
        --    ApplicationDefinition (0x81) command.
        --
        -- Format: 0x01, <protocolRev>, <numPanels>, (<mod.PANEL_TYPE>, <panelID>)...
        --
        -- protocolRev: The revision number of the protocol (Unsigned Int)
        -- numPanels: The number of panels connected (Unsigned Int)
        -- panelType: The code for the type of panel connected (Unsigned Int)
        -- panelID: The ID of the panel (Unsigned Int)
        --------------------------------------------------------------------------------
        local protocolRev = byteStringToNumber(data, 5, 4)
        local numberOfPanels = byteStringToNumber(data, 9, 4)
        local panels = {}
        local startNumber = 13
        for _=1, numberOfPanels do
            local currentPanelType = byteStringToNumber(data, startNumber, 4)
            startNumber = startNumber + 4
            local currentPanelID = byteStringToNumber(data, startNumber, 4)
            startNumber = startNumber + 4
            table.insert(panels, {
                ["panelID"] = currentPanelID,
                ["panelType"] = getPanelType(currentPanelType),
                ["data"] = data,
            })
        end
        --------------------------------------------------------------------------------
        -- Trigger callback:
        --------------------------------------------------------------------------------
        if protocolRev and numberOfPanels and mod._callback then
            mod._callback("INITIATE_COMMS", {
                ["protocolRev"] = protocolRev,
                ["numberOfPanels"] = numberOfPanels,
                ["panels"] = panels,
                ["data"] = data,
            })
        end
        --------------------------------------------------------------------------------
        -- Send Application Definition:
        --------------------------------------------------------------------------------
        if mod.automaticallySendApplicationDefinition == true then
            mod.send("APPLICATION_DEFINITION")
        end
    elseif id == mod.HUB_MESSAGE["PARAMETER_CHANGE"] then
        --------------------------------------------------------------------------------
        -- ParameterChange (0x02)
        --  * Requests that the application increment a parameter. The application needs
        --    to constrain the value to remain within its maximum and minimum values.
        --  * On receipt the application should respond to the Hub with the new
        --    absolute parameter value using the ParameterValue (0x82) command,
        --    if the value has changed.
        --
        -- Format: 0x02, <paramID>, <increment>
        --
        -- paramID: The ID value of the parameter (Unsigned Int)
        -- increment: The incremental value which should be applied to the parameter (Float)
        --------------------------------------------------------------------------------
        local paramID = byteStringToNumber(data, 5, 4)
        local increment = byteStringToFloat(data, 9, 4)
        if paramID and increment and mod._callback then
            mod._callback("PARAMETER_CHANGE", {
                ["paramID"] = paramID,
                ["increment"] = increment,
                ["data"] = data,
            })
        else
            log.ef("Error translating PARAMETER_CHANGE.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["PARAMETER_RESET"] then
        --------------------------------------------------------------------------------
        -- ParameterReset (0x03)
        --  * Requests that the application changes a parameter to its reset value.
        --  * On receipt the application should respond to the Hub with the new absolute
        --    parameter value using the ParameterValue (0x82) command, if the value
        --    has changed.
        --
        -- Format: 0x03, <paramID>
        --
        -- paramID: The ID value of the parameter (Unsigned Int)
        --------------------------------------------------------------------------------
        local paramID = byteStringToNumber(data, 5, 4)
        if paramID and mod._callback then
            mod._callback("PARAMETER_RESET", {
                ["paramID"] = paramID,
                ["data"] = data,
            })
        else
            log.ef("Error translating PARAMETER_RESET.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["PARAMETER_VALUE_REQUEST"] then
        --------------------------------------------------------------------------------
        -- ParameterValueRequest (0x04)
        --  * Requests that the application sends a ParameterValue (0x82) command
        --    to the Hub.
        --
        -- Format: 0x04, <paramID>
        --
        -- paramID: The ID value of the parameter (Unsigned Int)
        --------------------------------------------------------------------------------
        local paramID = byteStringToNumber(data, 5, 4)
        if paramID and mod._callback then
            mod._callback("PARAMETER_VALUE_REQUEST", {
                ["paramID"] = paramID,
                ["data"] = data,
            })
        else
            log.ef("Error translating PARAMETER_VALUE_REQUEST.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["MENU_CHANGE"] then
        --------------------------------------------------------------------------------
        -- MenuChange (0x05)
        --  * Requests the application change a menu index by +1 or -1.
        --  * We recommend that menus that only have two values (e.g. on/off) should
        --    toggle their state on receipt of either a +1 or -1 increment value.
        --    This will allow a single button to toggle the state of such an item
        --    without the need for separate ‘up’ and ‘down’ buttons.
        --
        -- Format: 0x05, <menuID>, < increment >
        --
        -- menuID: The ID value of the menu (Unsigned Int)
        -- increment: The incremental amount by which the menu index should be changed which will always be an integer value of +1 or -1 (Signed Int)
        --------------------------------------------------------------------------------
        local menuID = byteStringToNumber(data, 5, 4)
        local increment = byteStringToNumber(data, 9, 4, true)
        if menuID and increment and mod._callback then
            mod._callback("MENU_CHANGE", {
                ["menuID"] = menuID,
                ["increment"] = increment,
                ["data"] = data,
            })
        else
            log.ef("Error translating MENU_CHANGE.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["MENU_RESET"] then
        --------------------------------------------------------------------------------
        -- MenuReset (0x06)
        --  * Requests that the application sends a MenuString (0x83) command to the Hub.
        --
        -- Format: 0x06, <menuID>
        --
        -- menuID: The ID value of the menu (Unsigned Int)
        --------------------------------------------------------------------------------
        local menuID = byteStringToNumber(data, 5, 4)
        if menuID and mod._callback then
            mod._callback("MENU_RESET", {
                ["menuID"] = menuID,
                ["data"] = data,
            })
        else
            log.ef("Error translating MENU_RESET.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["MENU_STRING_REQUEST"] then
        --------------------------------------------------------------------------------
        -- MenuStringRequest (0x07)
        --  * Requests that the application sends a MenuString (0x83) command to the Hub.
        --  * On receipt, the application should respond to the Hub with the new menu
        --    value using the MenuString (0x83) command, if the menu has changed.
        --
        -- Format: 0x07, <menuID>
        --
        -- menuID: The ID value of the menu (Unsigned Int)
        --------------------------------------------------------------------------------
        local menuID = byteStringToNumber(data, 5, 4)
        if menuID and mod._callback then
            mod._callback("MENU_STRING_REQUEST", {
                ["menuID"] = menuID,
                ["data"] = data,
            })
        else
            log.ef("Error translating MENU_STRING_REQUEST.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["ACTION_ON"] then
        --------------------------------------------------------------------------------
        -- Action On (0x08)
        --  * Requests that the application performs the specified action.
        --
        -- Format: 0x08, <actionID>
        --
        -- actionID: The ID value of the action (Unsigned Int)
        --------------------------------------------------------------------------------
        local actionID = byteStringToNumber(data, 5, 4)
        if actionID and mod._callback then
            mod._callback("ACTION_ON", {
                ["actionID"] = actionID,
                ["data"] = data,
            })
        else
            log.ef("Error translating ACTION_ON.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["MODE_CHANGE"] then
        --------------------------------------------------------------------------------
        -- ModeChange (0x09)
        --  * Requests that the application changes to the specified mode.
        --
        -- Format: 0x09, <modeID>
        --
        -- modeID: The ID value of the mode (Unsigned Int)
        --------------------------------------------------------------------------------
        local modeID = byteStringToNumber(data, 5, 4)
        if modeID and mod._callback then
            mod._callback("MODE_CHANGE", {
                ["modeID"] = modeID,
                ["data"] = data,
            })
        else
            log.ef("Error translating MODE_CHANGE.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["TRANSPORT"] then
        --------------------------------------------------------------------------------
        -- Transport (0x0A)
        --  * Requests the application to move the currently active transport.
        --  * jogValue or shuttleValue will never both be set simultaneously
        --  * One revolution of the control represents 32 counts by default.
        --    The user will be able to adjust the sensitivity of Jog & Shuttle
        --    independently in the TUBE Mapper tool to send more or less than
        --    32 counts per revolution.
        --
        -- Format: 0x0A, <jogValue>, <shuttleValue>
        --
        -- jogValue: The number of jog steps to move the transport (Signed Int)
        -- shuttleValue: An incremental value to add to the shuttle speed (Signed Int)
        --------------------------------------------------------------------------------
        local jogValue = byteStringToNumber(data, 5, 4, true)
        local shuttleValue = byteStringToNumber(data, 9, 4, true)
        if jogValue and shuttleValue and mod._callback then
            mod._callback("TRANSPORT", {
                ["jogValue"] = jogValue,
                ["shuttleValue"] = shuttleValue,
                ["data"] = data,
            })
        else
            log.ef("Error translating TRANSPORT.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["ACTION_OFF"] then
        --------------------------------------------------------------------------------
        -- ActionOff (0x0B)
        --  * Requests that the application cancels the specified action.
        --  * This is typically sent when a button is released.
        --
        -- Format: 0x0B, <actionID>
        --
        -- actionID: The ID value of the action (Unsigned Int)
        --------------------------------------------------------------------------------
        local actionID = byteStringToNumber(data, 5, 4)
        if actionID and mod._callback then
            mod._callback("ACTION_OFF", {
                ["actionID"] = actionID,
                ["data"] = data,
            })
        else
            log.ef("Error translating ACTION_OFF.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["UNMANAGED_PANEL_CAPABILITIES"] then
        --------------------------------------------------------------------------------
        -- UnmanagedPanelCapabilities (0x30)
        --  * Only used when working in Unmanaged panel mode.
        --  * Sent in response to a UnmanagedPanelCapabilitiesRequest (0xA0) command.
        --  * The values returned are those given in the table in Section 18.
        --    Panel Data for Unmanaged Mode.
        --
        -- Format: 0x30, <panelID>, <numButtons>, <numEncoders>, <numDisplays>, <numDisplayLines>, <numDisplayChars>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        -- numButtons: The number of buttons on the panel (Unsigned Int)
        -- numEncoders: The number of encoders on the panel (Unsigned Int)
        -- numDisplays: The number of displays on the panel (Unsigned Int)
        -- numDisplayLines: The number of lines for each display on the panel (Unsigned Int)
        -- numDisplayChars: The number of characters on each line of each display on the panel (Unsigned Int)
        --------------------------------------------------------------------------------
        local panelID           = byteStringToNumber(data, 5, 4)
        local numButtons        = byteStringToNumber(data, 9, 4)
        local numEncoders       = byteStringToNumber(data, 13, 4)
        local numDisplays       = byteStringToNumber(data, 17, 4)
        local numDisplayLines   = byteStringToNumber(data, 21, 4)
        local numDisplayChars   = byteStringToNumber(data, 25, 4)
        if panelID and numButtons and numEncoders and numDisplays and numDisplayLines and numDisplayChars and mod._callback then
            mod._callback("UNMANAGED_PANEL_CAPABILITIES", {
                ["panelID"]             = panelID,
                ["numButtons"]          = numButtons,
                ["numEncoders"]         = numEncoders,
                ["numDisplays"]         = numDisplays,
                ["numDisplayLines"]     = numDisplayLines,
                ["numDisplayChars"]     = numDisplayChars,
                ["data"] = data,
            })
        else
            log.ef("Error translating UNMANAGED_PANEL_CAPABILITIES.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["UNMANAGED_BUTTON_DOWN"] then
        --------------------------------------------------------------------------------
        -- UnmanagedButtonDown (0x31)
        --  * Only used when working in Unmanaged panel mode
        --  * Issued when a button has been pressed
        --
        -- Format: 0x31, <panelID>, <buttonID>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        -- buttonID: The hardware ID of the button (Unsigned Int)
        --------------------------------------------------------------------------------
        local panelID = byteStringToNumber(data, 5, 4)
        local buttonID = byteStringToNumber(data, 9, 4)
        if panelID and buttonID and mod._callback then
            mod._callback("UNMANAGED_BUTTON_DOWN", {
                ["panelID"] = panelID,
                ["buttonID"] = buttonID,
                ["data"] = data,
            })
        else
            log.ef("Error translating UNMANAGED_BUTTON_DOWN.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["UNMANAGED_BUTTON_UP"] then
        --------------------------------------------------------------------------------
        -- UnmanagedButtonUp (0x32)
        --  * Only used when working in Unmanaged panel mode.
        --  * Issued when a button has been released
        --
        -- Format: 0x32, <panelID>, <buttonID>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        -- buttonID: The hardware ID of the button (Unsigned Int)
        --------------------------------------------------------------------------------
        local panelID = byteStringToNumber(data, 5, 4)
        local buttonID = byteStringToNumber(data, 9, 4)
        if panelID and buttonID and mod._callback then
            mod._callback("UNMANAGED_BUTTON_UP", {
                ["panelID"] = panelID,
                ["buttonID"] = buttonID,
                ["data"] = data,
            })
        else
            log.ef("Error translating UNMANAGED_BUTTON_UP.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["UNMANAGED_ENCODER_CHANGE"] then
        --------------------------------------------------------------------------------
        -- UnmanagedEncoderChange (0x33)
        --  * Only used when working in Unmanaged panel mode.
        --  * Issued when an encoder has been moved.
        --
        -- Format: 0x33, <panelID>, <encoderID>, <increment>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        -- paramID: The hardware ID of the encoder (Unsigned Int)
        -- increment: The incremental value (Float)
        --------------------------------------------------------------------------------
        local panelID = byteStringToNumber(data, 5, 4)
        local encoderID = byteStringToNumber(data, 9, 4)
        local increment = byteStringToFloat(data, 13, 4)
        if panelID and encoderID and increment and mod._callback then
            mod._callback("UNMANAGED_ENCODER_CHANGE", {
                ["panelID"] = panelID,
                ["encoderID"] = encoderID,
                ["increment"] = increment,
                ["data"] = data,
            })
        else
            log.ef("Error translating UNMANAGED_ENCODER_CHANGE.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    elseif id == mod.HUB_MESSAGE["UNMANAGED_DISPLAY_REFRESH"] then
        --------------------------------------------------------------------------------
        -- UnmanagedDisplayRefresh (0x34)
        --  * Only used when working in Unmanaged panel mode
        --  * Issued when a panel has been connected or the focus of the panel has
        --    been returned to your application.
        --  * On receipt your application should send all the current information to
        --    each display on the panel in question.
        --
        -- Format: 0x34, <panelID>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        --------------------------------------------------------------------------------
        local panelID = byteStringToNumber(data, 5, 4)
        if panelID and mod._callback then
            mod._callback("UNMANAGED_DISPLAY_REFRESH", {
                ["panelID"] = panelID,
                ["data"] = data,
            })
        else
            log.ef("Error translating UNMANAGED_DISPLAY_REFRESH.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end

    elseif id == mod.HUB_MESSAGE["PANEL_CONNECTION_STATE"] then
        --------------------------------------------------------------------------------
        -- PanelConnectionState (0x35)
        --  * Sent in response to a PanelConnectionStatesRequest (0xA5) command to
        --    report the current connected/disconnected status of a configured panel.
        --
        -- Format: 0x35, <panelID>, <state>
        --
        -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
        -- state: The connected state of the panel: 1 if connected, 0 if disconnected (Bool)
        --------------------------------------------------------------------------------
        local panelID = byteStringToNumber(data, 5, 4)
        local state = byteStringToBoolean(data, 9, 4)
        if panelID and state and mod._callback then
            mod._callback("PANEL_CONNECTION_STATE", {
                ["panelID"] = panelID,
                ["state"] = state,
                ["data"] = data,
            })
        else
            log.ef("Error translating PANEL_CONNECTION_STATE.")
            mod._callback("ERROR", {
                ["data"] = data
            })
        end
    end
end

-- separateHubCommands(data) -> none
-- Function
-- Separates multiple Hub Commands for processing.
--
-- Parameters:
--  * data - The raw data from the socket.
--
-- Returns:
--  * None
local function separateHubCommands(rawData)
    local numberOfBytesLeft = string.len(rawData)
    while numberOfBytesLeft ~= 0 do
        local currentPosition = (string.len(rawData) - numberOfBytesLeft) + 1
        local data = string.sub(rawData, currentPosition)
        local id = byteStringToNumber(data, 1, 4)
        if id == mod.HUB_MESSAGE["INITIATE_COMMS"] then
            --------------------------------------------------------------------------------
            -- InitiateComms (0x01)
            --  * Initiates communication between the Hub and the application.
            --  * Communicates the quantity, type and IDs of the panels which are
            --    configured to be connected in the panel-list.xml file. Note that this is
            --    not the same as the panels which are actually connected – just those
            --    which are expected to be connected.
            --  * The length is dictated by the number of panels connected as the details
            --    of each panel occupies 5 bytes.
            --  * On receipt the application should respond with the
            --    ApplicationDefinition (0x81) command.
            --
            -- Format: 0x01, <protocolRev>, <numPanels>, (<mod.PANEL_TYPE>, <panelID>)...
            --
            -- protocolRev: The revision number of the protocol (Unsigned Int)
            -- numPanels: The number of panels connected (Unsigned Int)
            -- panelType: The code for the type of panel connected (Unsigned Int)
            -- panelID: The ID of the panel (Unsigned Int)
            --------------------------------------------------------------------------------
            local numberOfPanels = byteStringToNumber(data, 9, 4)
            local length = (1 + 1 + 1 + (numberOfPanels * 1) + (numberOfPanels * 1)) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["PARAMETER_CHANGE"] then
            --------------------------------------------------------------------------------
            -- ParameterChange (0x02)
            --  * Requests that the application increment a parameter. The application needs
            --    to constrain the value to remain within its maximum and minimum values.
            --  * On receipt the application should respond to the Hub with the new
            --    absolute parameter value using the ParameterValue (0x82) command,
            --    if the value has changed.
            --
            -- Format: 0x02, <paramID>, <increment>
            --
            -- paramID: The ID value of the parameter (Unsigned Int)
            -- increment: The incremental value which should be applied to the parameter (Float)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["PARAMETER_RESET"] then
            --------------------------------------------------------------------------------
            -- ParameterReset (0x03)
            --  * Requests that the application changes a parameter to its reset value.
            --  * On receipt the application should respond to the Hub with the new absolute
            --    parameter value using the ParameterValue (0x82) command, if the value
            --    has changed.
            --
            -- Format: 0x03, <paramID>
            --
            -- paramID: The ID value of the parameter (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["PARAMETER_VALUE_REQUEST"] then
            --------------------------------------------------------------------------------
            -- ParameterValueRequest (0x04)
            --  * Requests that the application sends a ParameterValue (0x82) command
            --    to the Hub.
            --
            -- Format: 0x04, <paramID>
            --
            -- paramID: The ID value of the parameter (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["MENU_CHANGE"] then
            --------------------------------------------------------------------------------
            -- MenuChange (0x05)
            --  * Requests the application change a menu index by +1 or -1.
            --  * We recommend that menus that only have two values (e.g. on/off) should
            --    toggle their state on receipt of either a +1 or -1 increment value.
            --    This will allow a single button to toggle the state of such an item
            --    without the need for separate ‘up’ and ‘down’ buttons.
            --
            -- Format: 0x05, <menuID>, < increment >
            --
            -- menuID: The ID value of the menu (Unsigned Int)
            -- increment: The incremental amount by which the menu index should be changed which will always be an integer value of +1 or -1 (Signed Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["MENU_RESET"] then
            --------------------------------------------------------------------------------
            -- MenuReset (0x06)
            --  * Requests that the application sends a MenuString (0x83) command to the Hub.
            --
            -- Format: 0x06, <menuID>
            --
            -- menuID: The ID value of the menu (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["MENU_STRING_REQUEST"] then
            --------------------------------------------------------------------------------
            -- MenuStringRequest (0x07)
            --  * Requests that the application sends a MenuString (0x83) command to the Hub.
            --  * On receipt, the application should respond to the Hub with the new menu
            --    value using the MenuString (0x83) command, if the menu has changed.
            --
            -- Format: 0x07, <menuID>
            --
            -- menuID: The ID value of the menu (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["ACTION_ON"] then
            --------------------------------------------------------------------------------
            -- Action On (0x08)
            --  * Requests that the application performs the specified action.
            --
            -- Format: 0x08, <actionID>
            --
            -- actionID: The ID value of the action (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["MODE_CHANGE"] then
            --------------------------------------------------------------------------------
            -- ModeChange (0x09)
            --  * Requests that the application changes to the specified mode.
            --
            -- Format: 0x09, <modeID>
            --
            -- modeID: The ID value of the mode (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["TRANSPORT"] then
            --------------------------------------------------------------------------------
            -- Transport (0x0A)
            --  * Requests the application to move the currently active transport.
            --  * jogValue or shuttleValue will never both be set simultaneously
            --  * One revolution of the control represents 32 counts by default.
            --    The user will be able to adjust the sensitivity of Jog & Shuttle
            --    independently in the TUBE Mapper tool to send more or less than
            --    32 counts per revolution.
            --
            -- Format: 0x0A, <jogValue>, <shuttleValue>
            --
            -- jogValue: The number of jog steps to move the transport (Signed Int)
            -- shuttleValue: An incremental value to add to the shuttle speed (Signed Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["ACTION_OFF"] then
            --------------------------------------------------------------------------------
            -- ActionOff (0x0B)
            --  * Requests that the application cancels the specified action.
            --  * This is typically sent when a button is released.
            --
            -- Format: 0x0B, <actionID>
            --
            -- actionID: The ID value of the action (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["UNMANAGED_PANEL_CAPABILITIES"] then
            --------------------------------------------------------------------------------
            -- UnmanagedPanelCapabilities (0x30)
            --  * Only used when working in Unmanaged panel mode.
            --  * Sent in response to a UnmanagedPanelCapabilitiesRequest (0xA0) command.
            --  * The values returned are those given in the table in Section 18.
            --    Panel Data for Unmanaged Mode.
            --
            -- Format: 0x30, <panelID>, <numButtons>, <numEncoders>, <numDisplays>, <numDisplayLines>, <numDisplayChars>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- numButtons: The number of buttons on the panel (Unsigned Int)
            -- numEncoders: The number of encoders on the panel (Unsigned Int)
            -- numDisplays: The number of displays on the panel (Unsigned Int)
            -- numDisplayLines: The number of lines for each display on the panel (Unsigned Int)
            -- numDisplayChars: The number of characters on each line of each display on the panel (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = 7 * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["UNMANAGED_BUTTON_DOWN"] then
            --------------------------------------------------------------------------------
            -- UnmanagedButtonDown (0x31)
            --  * Only used when working in Unmanaged panel mode
            --  * Issued when a button has been pressed
            --
            -- Format: 0x31, <panelID>, <buttonID>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- buttonID: The hardware ID of the button (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["UNMANAGED_BUTTON_UP"] then
            --------------------------------------------------------------------------------
            -- UnmanagedButtonUp (0x32)
            --  * Only used when working in Unmanaged panel mode.
            --  * Issued when a button has been released
            --
            -- Format: 0x32, <panelID>, <buttonID>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- buttonID: The hardware ID of the button (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["UNMANAGED_ENCODER_CHANGE"] then
            --------------------------------------------------------------------------------
            -- UnmanagedEncoderChange (0x33)
            --  * Only used when working in Unmanaged panel mode.
            --  * Issued when an encoder has been moved.
            --
            -- Format: 0x33, <panelID>, <encoderID>, <increment>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- paramID: The hardware ID of the encoder (Unsigned Int)
            -- increment: The incremental value (Float)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["UNMANAGED_DISPLAY_REFRESH"] then
            --------------------------------------------------------------------------------
            -- UnmanagedDisplayRefresh (0x34)
            --  * Only used when working in Unmanaged panel mode
            --  * Issued when a panel has been connected or the focus of the panel has
            --    been returned to your application.
            --  * On receipt your application should send all the current information to
            --    each display on the panel in question.
            --
            -- Format: 0x34, <panelID>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            --------------------------------------------------------------------------------
            local length = (1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        elseif id == mod.HUB_MESSAGE["PANEL_CONNECTION_STATE"] then
            --------------------------------------------------------------------------------
            -- PanelConnectionState (0x35)
            --  * Sent in response to a PanelConnectionStatesRequest (0xA5) command to
            --    report the current connected/disconnected status of a configured panel.
            --
            -- Format: 0x35, <panelID>, <state>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- state: The connected state of the panel: 1 if connected, 0 if disconnected (Bool)
            --------------------------------------------------------------------------------
            local length = (1 + 1 + 1) * 4
            local commandData = string.sub(data, 1, length)
            processHubCommand(commandData)
            numberOfBytesLeft = numberOfBytesLeft - length
        else
            --------------------------------------------------------------------------------
            -- Unknown Command:
            --------------------------------------------------------------------------------
            if mod._callback then
                mod._callback("UNKNOWN", {
                    ["data"] = rawData
                })
            end
            return
        end
    end
end

--------------------------------------------------------------------------------
-- PRIVATE VARIABLES:
--------------------------------------------------------------------------------

-- hs.tangent._readBytesRemaining -> number
-- Variable
-- Number of read bytes remaining.
mod._readBytesRemaining = 0

-- hs.tangent._applicationName -> number
-- Variable
-- Application name as specified in `hs.tangent.connect()`
mod._applicationName = nil

-- hs.tangent._systemPath -> number
-- Variable
-- A string containing the absolute path of the directory that contains the Controls and Default Map XML files.
mod._systemPath = nil

-- hs.tangent._userPath -> number
-- Variable
-- A string containing the absolute path of the directory that contains the User’s Default Map XML files.
mod._userPath = nil

--------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS & METHODS:
--------------------------------------------------------------------------------

--- hs.tangent.ipAddress -> number
--- Variable
--- IP Address that the Tangent Hub is located at. Defaults to 127.0.0.1.
mod.ipAddress = "127.0.0.1"

--- hs.tangent.port -> number
--- Variable
--- The port that Tangent Hub monitors. Defaults to 64246.
mod.port = 64246

--- hs.tangent.interval -> number
--- Variable
--- How often we check for new socket messages. Defaults to 0.001.
mod.interval = 0.001

--- hs.tangent.automaticallySendApplicationDefinition -> boolean
--- Variable
--- Automatically send the "Application Definition" response. Defaults to `true`.
mod.automaticallySendApplicationDefinition = true

--- hs.tangent.setLogLevel(loglevel) -> none
--- Function
--- Sets the Log Level.
---
--- Parameters:
---  * loglevel - can be 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose'; or a corresponding number between 0 and 5
---
--- Returns:
---  * None
function mod.setLogLevel(loglevel)
    log:setLogLevel(loglevel)
    socket.setLogLevel(loglevel)
end

--- hs.tangent.isTangentHubInstalled() -> boolean
--- Function
--- Checks to see whether or not the Tangent Hub software is installed.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Tangent Hub is installed otherwise `false`.
function mod.isTangentHubInstalled()
    if doesFileExist("/Library/Application Support/Tangent/Hub/TangentHub") then
        return true
    else
        return false
    end
end

--- hs.tangent.callback() -> boolean
--- Function
--- Sets a callback when new messages are received.
---
--- Parameters:
---  * callbackFn - a function to set as the callback for `hs.tangent`. If the value provided is `nil`, any currently existing callback function is removed.
---
--- Returns:
---  * `true` if successful otherwise `false`
---
--- Notes:
---  * Full documentation for the Tangent API can be downloaded [here](http://www.tangentwave.co.uk/download/developer-support-pack/).
---  * The callback function should expect 2 arguments and should not return anything:
---    * id - the message ID of the incoming message
---    * metadata - A table of data for the Tangent command (see below).
---  * The metadata table will return the following, depending on the `id` for the callback:
---    * `CONNECTED` - Connection To Tangent Hub successfully established.
---    * `INITIATE_COMMS` - Initiates communication between the Hub and the application.
---      * `protocolRev` - The revision number of the protocol.
---      * `numPanels` - The number of panels connected.
---      * `panels`
---        * `panelID` - The ID of the panel.
---        * `panelType` - The type of panel connected.
---      * `data` - The raw data from the Tangent Hub
---    * `PARAMETER_CHANGE` - Requests that the application increment a parameter.
---      * `paramID` - The ID value of the parameter.
---      * `increment` - The incremental value which should be applied to the parameter.
---      * `data` - The raw data from the Tangent Hub
---    * `PARAMETER_RESET` - Requests that the application changes a parameter to its reset value.
---      * `paramID` - The ID value of the parameter.
---      * `data` - The raw data from the Tangent Hub
---    * `PARAMETER_VALUE_REQUEST` - Requests that the application sends a `ParameterValue (0x82)` command to the Hub.
---      * `paramID` - The ID value of the parameter.
---      * `data` - The raw data from the Tangent Hub
---    * `MENU_CHANGE` - Requests the application change a menu index by +1 or -1.
---      * `menuID` - The ID value of the menu.
---      * `increment` - The incremental amount by which the menu index should be changed which will always be an integer value of +1 or -1.
---      * `data` - The raw data from the Tangent Hub
---    * `MENU_RESET` - Requests that the application changes a menu to its reset value.
---      * `menuID` - The ID value of the menu.
---      * `data` - The raw data from the Tangent Hub
---    * `MENU_STRING_REQUEST` - Requests that the application sends a `MenuString (0x83)` command to the Hub.
---      * `menuID` - The ID value of the menu.
---      * `data` - The raw data from the Tangent Hub
---    * `ACTION_ON` - Requests that the application performs the specified action.
---      * `actionID` - The ID value of the action.
---      * `data` - The raw data from the Tangent Hub
---    * `MODE_CHANGE` - Requests that the application changes to the specified mode.
---      * `modeID` - The ID value of the mode.
---      * `data` - The raw data from the Tangent Hub
---    * `TRANSPORT` - Requests the application to move the currently active transport.
---      * `jogValue` - The number of jog steps to move the transport.
---      * `shuttleValue` - An incremental value to add to the shuttle speed.
---      * `data` - The raw data from the Tangent Hub
---    * `ACTION_OFF` - Requests that the application cancels the specified action.
---      * `actionID` - The ID value of the action.
---      * `data` - The raw data from the Tangent Hub
---    * `UNMANAGED_PANEL_CAPABILITIES` - Only used when working in Unmanaged panel mode. Sent in response to a `UnmanagedPanelCapabilitiesRequest (0xA0)` command.
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `numButtons` - The number of buttons on the panel.
---      * `numEncoders` - The number of encoders on the panel.
---      * `numDisplays` - The number of displays on the panel.
---      * `numDisplayLines` - The number of lines for each display on the panel.
---      * `numDisplayChars` - The number of characters on each line of each display on the panel.
---      * `data` - The raw data from the Tangent Hub
---    * `UNMANAGED_BUTTON_DOWN` - Only used when working in Unmanaged panel mode. Issued when a button has been pressed.
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `buttonID` - The hardware ID of the button
---      * `data` - The raw data from the Tangent Hub.
---    * `UNMANAGED_BUTTON_UP` - Only used when working in Unmanaged panel mode. Issued when a button has been released.
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `buttonID` - The hardware ID of the button.
---      * `data` - The raw data from the Tangent Hub
---    * `UNMANAGED_ENCODER_CHANGE` - Only used when working in Unmanaged panel mode. Issued when an encoder has been moved.
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `paramID` - The hardware ID of the encoder.
---      * `increment` - The incremental value.
---      * `data` - The raw data from the Tangent Hub
---    * `UNMANAGED_DISPLAY_REFRESH` - Only used when working in Unmanaged panel mode. Issued when a panel has been connected or the focus of the panel has been returned to your application.
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `data` - The raw data from the Tangent Hub
---    * `PANEL_CONNECTION_STATE`
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `state` - The connected state of the panel, `true` if connected, `false` if disconnected.
---      * `data` - The raw data from the Tangent Hub
function mod.callback(callbackFn)
    if type(callbackFn) == "function" then
        mod._callback = callbackFn
        return true
    elseif type(callbackFn) == "nil" then
        mod._callback = nil
        return true
    else
        log.ef("Callback recieved an invalid type: %s", type(callbackFn))
        return false
    end
end

--- hs.tangent.connected() -> boolean
--- Function
--- Checks to see whether or not you're successfully connected to the Tangent Hub.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if connected, otherwise `false`
function mod.connected()
    return mod._socket and mod._socket:connected()
end

--- hs.tangent.send(id, metadata) -> boolean, string
--- Function
--- Sends a message to the Tangent Hub.
---
--- Parameters:
---  * id - The ID of the message you want to send as defined in `hs.tangent.APP_MESSAGE`
---  * metadata - A table of values as explained below.
---
--- Returns:
---  * success - `true` if connected, otherwise `false`
---  * errorMessage - An error message if an error occurs, as a string
---
--- Notes:
---  * Full documentation for the Tangent API can be downloaded [here](http://www.tangentwave.co.uk/download/developer-support-pack/).
---  * The metadata table will accept the following, depending on the `id` provided:
---    * `APPLICATION_DEFINITION` - This is sent in response to the `InitiateComms (0x01)` command and establishes communication between the application and the hub.
---      * `applicationName` - An string containing the name of the application.
---      * `systemPath` - A string containing the absolute path of the directory that contains the Controls and Default Map XML files.
---      * `userPath` - A string containing the absolute path of the directory that contains the User’s Default Map XML files.
---    * `PARAMETER_VALUE` - Updates the Hub with a parameter value.
---      * `paramID` - The ID value of the parameter.
---      * `value` - The current value of the parameter.
---      * `atDefault` - `true` if the value represents the default, otherwise `false`.
---    * `MENU_STRING` - Updates the Hub with a menu value.
---      * `menuID` - The ID value of the menu.
---      * `valueStr` - The current ‘value’ of the parameter represented as a string.
---      * `atDefault` - `true` if the value represents the default, otherwise `false`.
---    * `ALL_CHANGE` - Tells the Hub that a large number of software-controls have changed.
---    * `MODE_VALUE`
---      * `modeID` - The ID value of the mode.
---    * `DISPLAY_TEXT`
---      * `stringOne` - A line of status text.
---      * `stringOneDoubleHeight` - `true` if the string is to be printed double height, otherwise `false`.
---      * [`stringTwo`] - An optional line of status text.
---      * [`stringTwoDoubleHeight`] - `true` if the string is to be printed double height, otherwise `false` (required if `stringTwo` is supplied).
---      * [`stringThree`] - An optional line of status text.
---      * [`stringThreeDoubleHeight`] - `true` if the string is to be printed double height, otherwise `false` (required if `stringThree` is supplied).
---    * `UNMANAGED_PANEL_CAPABILITIES_REQUEST`
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---    * `UNMANAGED_DISPLAY_WRITE`
---      * `panelID` - The ID of the panel as reported in the `InitiateComms` command.
---      * `displayID` - The ID of the display to be written to.
---      * `lineNum` - The line number of the display to be written to with 0 as the top line.
---      * `pos` - The position on the line to start writing from with 0 as the first column.
---      * `dispStr` - A line of text.
---    * `RENAME_CONTROL`
---      * `targetID` - The id of any application defined Parameter, Menu, Action or Mode.
---      * `nameStr` - The new name string.
---    * `HIGHLIGHT_CONTROL`
---      * `targetID` - The id of any application defined Parameter, Menu, Action or Mode.
---      * `state` - The state to set, `true` for highlighted, `false` for clear.
---    * `INDICATE_CONTROL`
---      * `targetID` - The id of any application defined Action or Mode.
---      * `state` - The state to set, `true` for indicated, `false` for clear.
---    * `REQUEST_PANEL_CONNECTION_STATES` - Requests the Hub to respond with a sequence of PanelConnectionState (0x35) commands to report the connected/disconnected status of each configured panel.
function mod.send(id, metadata)
    if mod._socket and mod.connected() == true then
        --------------------------------------------------------------------------------
        -- Error Checking:
        --------------------------------------------------------------------------------
        if not id then
            return false, "The 'id' parameter is required."
        end
        --------------------------------------------------------------------------------
        -- Command Processing:
        --------------------------------------------------------------------------------
        if id == "APPLICATION_DEFINITION" or id == mod.APP_MESSAGE["APPLICATION_DEFINITION"] then
            --------------------------------------------------------------------------------
            -- ApplicationDefinition (0x81)
            --  * This is sent in response to the InitiateComms (0x01) command and
            --    establishes communication between the application and the hub.
            --  * Sends the application type and some file directory details to the hub.
            --  * If your application manages multiple user settings internally then this
            --    command should also be sent each time the user changes. This will notify
            --    the Hub to reload the preference files for the new user.
            --
            -- Format: 0x81, <appStrLen>, < appStr>, <sysDirStrLen>, <sysDirStr>, <userDirStrLen>, <userDirStr>
            --
            -- appStrLen: The length of appStr (Unsigned Int)
            -- appStr: A string containing the name of the application (Character String)
            -- sysDirStrLen: The length of sysDirStr (Unsigned Int)
            -- sysDirStr: A string containing the absolute path of the directory that contains the Controls and Default Map XML files (Path String)
            -- usrDirStrLen: The length of usrDirStr (Unsigned Int)
            -- usrDirStr: A string containing the absolute path of the directory that contains the User’s Default Map XML files (Path String)
            --------------------------------------------------------------------------------
            if not metadata then
                --------------------------------------------------------------------------------
                -- If no metadata is supplied, then use the values stored from
                -- hs.tangent.connect():
                --------------------------------------------------------------------------------
                local byteString =  numberToByteString(mod.APP_MESSAGE["APPLICATION_DEFINITION"]) ..
                                    numberToByteString(#mod._applicationName) ..
                                    mod._applicationName ..
                                    numberToByteString(#mod._systemPath) ..
                                    mod._systemPath
                if mod._userPath then
                    byteString = byteString .. numberToByteString(#mod._userPath) .. mod._userPath
                else
                    byteString = byteString .. numberToByteString(0)
                end
                mod._socket:send(numberToByteString(#byteString)..byteString)
            else
                if not metadata or type(metadata) ~= "table" then
                    return false, "The 'metadata' table is required."
                end
                if not metadata.applicationName then
                    return false, "Missing or invalid paramater: applicationName."
                end
                if not metadata.systemPath or doesDirectoryExist(metadata.systemPath) == false then
                    return false, "Missing or invalid paramater: systemPath."
                end
                if metadata.userPath and doesDirectoryExist(metadata.userPath) == false then
                    return false, "Missing or invalid paramater: userPath."
                end
                local byteString =  numberToByteString(mod.APP_MESSAGE["APPLICATION_DEFINITION"]) ..
                                    numberToByteString(#metadata.applicationName) ..
                                    metadata.applicationName ..
                                    numberToByteString(#metadata.systemPath) ..
                                    metadata.systemPath
                if metadata.userPath then
                    byteString = byteString .. numberToByteString(#metadata.userPath) .. metadata.userPath
                else
                    byteString = byteString .. numberToByteString(0)
                end
                mod._socket:send(numberToByteString(#byteString)..byteString)
            end
        elseif id == "PARAMETER_VALUE" or id == mod.APP_MESSAGE["PARAMETER_VALUE"] then
            --------------------------------------------------------------------------------
            -- ParameterValue (0x82)
            --  * Updates the Hub with a parameter value.
            --  * The Hub then updates the displays of any panels which are currently
            --    showing the parameter value.
            --
            -- Format: 0x82, <paramID>, <value>, <atDefault>
            --
            -- paramID: The ID value of the parameter (Unsigned Int)
            -- value: The current value of the parameter (Float)
            -- atDefault: True if the value represents the default. Otherwise false (Bool)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.paramID then
                return false, "Missing or invalid paramater: paramID."
            end
            if not metadata.value then
                return false, "Missing or invalid paramater: value."
            end
            if type(metadata.atDefault) ~= "boolean" then
                return false, "Missing or invalid paramater: atDefault."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["PARAMETER_VALUE"]) ..
                            numberToByteString(metadata.paramID) ..
                            floatToByteString(metadata.value) ..
                            booleanToByteString(metadata.atDefault)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "MENU_STRING" or id == mod.APP_MESSAGE["MENU_STRING"] then
            --------------------------------------------------------------------------------
            -- MenuString (0x83)
            --  * Updates the Hub with a menu value.
            --  * The Hub then updates the displays of any panels which are currently
            --    showing the menu.
            --  * If a valueStrLen of 0 is sent then no valueStr data will follow and the
            --    Hub will not attempt to display a value for the menu. However the
            --    atDefault flag will still be recognised.
            --
            -- Format: 0x83, <menuID>, <valueStrLen>, <valueStr>, <atDefault>
            --
            -- menuID: The ID value of the menu (Unsigned Int)
            -- valueStrLen: The length of valueStr (Unsigned Int)
            -- valueStr: The current ‘value’ of the parameter represented as a string (Character String)
            -- atDefault: True if the value represents the default. Otherwise false (Bool)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.menuID then
                return false, "Missing or invalid paramater: menuID."
            end
            if not metadata.valueStr then
                return false, "Missing or invalid paramater: valueStr."
            end
            if type(metadata.atDefault) ~= "boolean" then
                return false, "Missing or invalid paramater: atDefault."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["MENU_STRING"]) ..
                               numberToByteString(metadata.menuID) ..
                               numberToByteString(#metadata.valueStr) ..
                               metadata.valueStr ..
                               booleanToByteString(metadata.atDefault)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "ALL_CHANGE" or id == mod.APP_MESSAGE["ALL_CHANGE"] then
            --------------------------------------------------------------------------------
            -- AllChange (0x84)
            --  * Tells the Hub that a large number of software-controls have changed.
            --  * The Hub responds by requesting all the current values of
            --    software-controls it is currently controlling.
            --
            -- Format: 0x84
            --------------------------------------------------------------------------------
            local byteString = numberToByteString(mod.APP_MESSAGE["ALL_CHANGE"])
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "MODE_VALUE" or id == mod.APP_MESSAGE["MODE_VALUE"] then
            --------------------------------------------------------------------------------
            -- ModeValue (0x85)
            --  * Updates the Hub with a mode value.
            --  * The Hub then changes mode and requests all the current values of
            --    software-controls it is controlling.
            --
            -- Format: 0x85, <modeID>
            --
            -- modeID: The ID value of the mode (Unsigned Int)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.modeID then
                return false, "Missing or invalid paramater: modeID."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["MODE_VALUE"]) ..
                               numberToByteString(metadata.modeID)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "DISPLAY_TEXT" or id == mod.APP_MESSAGE["DISPLAY_TEXT"] then
            --------------------------------------------------------------------------------
            -- DisplayText (0x86)
            --  * Updates the Hub with a number of character strings that will be displayed
            --    on connected panels if there is space.
            --  * Strings may either be 32 character, single height or 16 character
            --    double-height. They will be displayed in the order received; the first
            --    string displayed at the top of the display.
            --  * If a string is not defined as double-height then it will occupy the
            --    next line.
            --  * If a string is defined as double-height then it will occupy the next
            --    2 lines.
            --  * The maximum number of lines which will be used by the application
            --    must be indicated in the Controls XML file.
            --  * If a stateStrLen value of 0 is passed then the line will not be
            --    overwritten with any information. In this circumstance no data should be
            --    passed for stateStr and doubleHeight. The next byte will be the
            --    stateStrLen for the next string.
            --
            -- Format: 0x86, <numStrings>, (<stateStrLen>, <stateStr>, <doubleHeight>)...
            --
            -- numStrings: The number of strings to follow (Unsigned Int)
            -- stateStrLen: The length of stateStr (Unsigned Int)
            -- stateStr: A line of status text (Character String)
            -- doubleHeight: True if the string is to be printed double height. Otherwise false (Bool)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.stringOne or type(metadata.stringOne) ~= "string" then
                return false, "Missing or invalid paramater: stringOne."
            end
            if type(metadata.stringOneDoubleHeight) ~= "boolean" then
                return false, "Missing or invalid paramater: stringOneDoubleHeight."
            end
            if metadata.stringTwo and type(metadata.stringTwo) ~= "string" then
                return false, "Missing or invalid paramater: stringTwo."
            end
            if metadata.stringTwo and type(metadata.stringTwoDoubleHeight) ~= "boolean" then
                return false, "Missing or invalid paramater: stringTwoDoubleHeight."
            end
            if metadata.stringThree and type(metadata.stringThree) ~= "string" then
                return false, "Missing or invalid paramater: stringThree."
            end
            if metadata.stringThree and type(metadata.stringThreeDoubleHeight) ~= "boolean" then
                return false, "Missing or invalid paramater: stringThreeDoubleHeight."
            end
            local numStrings = 1
            if metadata.stringTwo then numStrings = 2 end
            if metadata.stringThree then numStrings = 3 end
            local byteString =  numberToByteString(mod.APP_MESSAGE["DISPLAY_TEXT"]) ..
                                numberToByteString(numStrings) ..
                                numberToByteString(#metadata.stringOne) ..
                                metadata.stringOne ..
                                booleanToByteString(metadata.stringOneDoubleHeight)
            if numStrings == 2 then
                byteString =    byteString ..
                                numberToByteString(#metadata.stringTwo) ..
                                metadata.stringTwo ..
                                booleanToByteString(metadata.stringTwoDoubleHeight)
            end
            if numStrings == 3 then
                byteString =    byteString ..
                                numberToByteString(#metadata.stringThree) ..
                                metadata.stringThree ..
                                booleanToByteString(metadata.stringThreeDoubleHeight)
            end
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "UNMANAGED_PANEL_CAPABILITIES_REQUEST" or id == mod.APP_MESSAGE["UNMANAGED_PANEL_CAPABILITIES_REQUEST"] then
            --------------------------------------------------------------------------------
            -- UnmanagedPanelCapabilitiesRequest (0xA0)
            --  * Only used when working in Unmanaged panel mode
            --  * Requests the Hub to respond with an UnmanagedPanelCapabilities (0x30)
            --    command.
            --
            -- Format: 0xA0, <panelID>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.panelID then
                return false, "Missing or invalid paramater: panelID."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["UNMANAGED_PANEL_CAPABILITIES_REQUEST"]) ..
                               numberToByteString(metadata.panelID)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "UNMANAGED_DISPLAY_WRITE" or id == mod.APP_MESSAGE["UNMANAGED_DISPLAY_WRITE"] then
            --------------------------------------------------------------------------------
            -- UnmanagedDisplayWrite (0xA1)
            --  * Only used when working in Unmanaged panel mode.
            --  * Updates the Hub with text that will be displayed on a specific panel at
            --    the given line and starting position where supported by the panel
            --    capabilities.
            --   * If the most significant bit of any individual text character in dispStr
            --     is set it will be displayed as inversed with dark text on a light
            --     background.
            --
            -- Format: 0xA1, <panelID>, <displayID>, <lineNum>, <pos>, <dispStrLen>, <dispStr>
            --
            -- panelID: The ID of the panel as reported in the InitiateComms command (Unsigned Int)
            -- displayID: The ID of the display to be written to (Unsigned Int)
            -- lineNum: The line number of the display to be written to with 0 as the top line (Unsigned Int)
            -- pos: The position on the line to start writing from with 0 as the first column (Unsigned Int)
            -- dispStrLen: The length of dispStr (Unsigned Int)
            -- dispStr: A line of text (Character String)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.panelID then
                return false, "Missing or invalid paramater: panelID."
            end
            if not metadata.displayID then
                return false, "Missing or invalid paramater: displayID."
            end
            if not metadata.lineNum then
                return false, "Missing or invalid paramater: lineNum."
            end
            if not metadata.pos then
                return false, "Missing or invalid paramater: pos."
            end
            if not metadata.dispStr then
                return false, "Missing or invalid paramater: dispStr."
            end
            local byteString =  numberToByteString(mod.APP_MESSAGE["UNMANAGED_DISPLAY_WRITE"]) ..
                                numberToByteString(metadata.panelID) ..
                                numberToByteString(metadata.displayID) ..
                                numberToByteString(metadata.lineNum) ..
                                numberToByteString(metadata.pos) ..
                                numberToByteString(#metadata.dispStr) ..
                                metadata.dispStr
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "RENAME_CONTROL" or id == mod.APP_MESSAGE["RENAME_CONTROL"] then
            --------------------------------------------------------------------------------
            -- RenameControl (0xA2)
            --  * Renames a control dynamically.
            --  * The string supplied will replace the normal text which has been
            --    derived from the Controls XML file.
            --  * To remove any existing replacement name set nameStrLen to zero,
            --    this will remove any renaming and return the system to the normal
            --    display text
            --  * When applied to Modes, the string displayed on buttons which mapped to
            --    the reserved Go To Mode action for this particular mode will also change.
            --
            -- Format: 0xA2, <targetID>, <nameStrLen>, <nameStr>
            --
            -- targetID: The id of any application defined Parameter, Menu, Action or Mode (Unsigned Int)
            -- nameStrLen: The length of nameStr (Unsigned Int)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.targetID then
                return false, "Missing or invalid paramater: targetID."
            end
            if not metadata.nameStr then
                return false, "Missing or invalid paramater: nameStr."
            end
            local byteString =  numberToByteString(mod.APP_MESSAGE["RENAME_CONTROL"]) ..
                                numberToByteString(#metadata.nameStr) ..
                                numberToByteString(metadata.nameStr)
            mod._socket:send(numberToByteString(#byteString) .. byteString)
        elseif id == "HIGHLIGHT_CONTROL" or id == mod.APP_MESSAGE["HIGHLIGHT_CONTROL"] then
            --------------------------------------------------------------------------------
            -- HighlightControl (0xA3)
            --  * Highlights the control on any panel where this feature is available.
            --  * When applied to Modes, buttons which are mapped to the reserved Go To
            --    Mode action for this particular mode will highlight.
            --
            -- Format: 0xA3, <targetID>, <state>
            --
            -- targetID: The id of any application defined Parameter, Menu, Action or Mode (Unsigned Int)
            -- state: The state to set. 1 for highlighted, 0 for clear (Unsigned Int)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.targetID then
                return false, "Missing or invalid paramater: targetID."
            end
            if type(metadata.state) ~= "boolean" then
                return false, "Missing or invalid paramater: state."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["HIGHLIGHT_CONTROL"]) ..
                               numberToByteString(metadata.targetID) ..
                               booleanToByteString(metadata.state)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "INDICATE_CONTROL" or id == mod.APP_MESSAGE["INDICATE_CONTROL"] then
            --------------------------------------------------------------------------------
            -- IndicateControl (0xA4)
            --  * Sets the Indicator of the control on any panel where this feature is
            --    available.
            --  * This indicator is driven by the atDefault argument for Parameters and
            --    Menus. This command therefore only applies to controls mapped to Actions
            --    and Modes.
            --  * When applied to Modes, buttons which are mapped to the reserved Go To
            --    Mode action for this particular mode will have their indicator set.
            --
            -- Format: 0xA4, <targetID>, <state>
            --
            -- targetID: The id of any application defined Action or Mode (Unsigned Int)
            -- state: The state to set. 1 for indicated, 0 for clear (Unsigned Int)
            --------------------------------------------------------------------------------
            if not metadata or type(metadata) ~= "table" then
                return false, "The 'metadata' table is required."
            end
            if not metadata.targetID then
                return false, "Missing or invalid paramater: targetID."
            end
            if type(metadata.state) ~= "boolean" then
                return false, "Missing or invalid paramater: state."
            end
            local byteString = numberToByteString(mod.APP_MESSAGE["INDICATE_CONTROL"]) ..
                               numberToByteString(metadata.targetID) ..
                               booleanToByteString(metadata.state)
            mod._socket:send(numberToByteString(#byteString)..byteString)
        elseif id == "REQUEST_PANEL_CONNECTION_STATES" or id == mod.APP_MESSAGE["REQUEST_PANEL_CONNECTION_STATES"] then
            --------------------------------------------------------------------------------
            -- PanelConnectionStatesRequest (0xA5)
            --  * Requests the Hub to respond with a sequence of PanelConnectionState
            --    (0x35) commands to report the connected/disconnected status of each
            --    configured panel.
            --  * A single request may result in multiple state responses.
            --
            -- Format: 0xA5
            --------------------------------------------------------------------------------
            local byteString = numberToByteString(mod.APP_MESSAGE["REQUEST_PANEL_CONNECTION_STATES"])
            mod._socket:send(numberToByteString(#byteString)..byteString)
        else
            --------------------------------------------------------------------------------
            -- Unknown Command:
            --------------------------------------------------------------------------------
            return false, "Unrecognised ID. Please refer to extension documentation for a list of possible IDs."
        end
    else
        return false, "Not connected to Tangent Hub."
    end
    --------------------------------------------------------------------------------
    -- Success!
    --------------------------------------------------------------------------------
    return true, ""
end

--- hs.tangent.disconnect() -> none
--- Function
--- Disconnects from the Tangent Hub.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.disconnect()
    if mod._socket then
        mod._socket:disconnect()
        mod._socket = nil
    end
end

--- hs.tangent.connect(applicationName, systemPath[, userPath]) -> boolean, errorMessage
--- Function
--- Connects to the Tangent Hub.
---
--- Parameters:
---  * applicationName - Your application name as a string
---  * systemPath - A string containing the absolute path of the directory that contains the Controls and Default Map XML files.
---  * [userPath] - An optional string containing the absolute path of the directory that contains the User’s Default Map XML files.
---
--- Returns:
---  * success - `true` on success, otherwise `nil`
---  * errorMessage - The error messages as a string or `nil` if `success` is `true`.
function mod.connect(applicationName, systemPath, userPath)

    --------------------------------------------------------------------------------
    -- Check Paramaters:
    --------------------------------------------------------------------------------
    if not applicationName or type(applicationName) ~= "string" then
        return nil, "applicationName is a required string."
    end
    if systemPath and type(systemPath) == "string" then
        local attr = fs.attributes(systemPath)
        if not attr or attr.mode ~= 'directory' then
            return nil, "systemPath must be a valid path."
        end
    else
        return nil, "systemPath is a required string."
    end
    if userPath and type(userPath) == "string" then
        local attr = fs.attributes(userPath)
        if not attr or attr.mode ~= 'directory' then
            return nil, "userPath must be a valid path."
        end
    end

    --------------------------------------------------------------------------------
    -- Save values for later:
    --------------------------------------------------------------------------------
    mod._applicationName = applicationName
    mod._systemPath = systemPath
    mod._userPath = userPath

    --------------------------------------------------------------------------------
    -- Connect to Tangent Hub:
    --------------------------------------------------------------------------------
    mod._socket = socket.new()
        :setCallback(function(data)
            if mod._readBytesRemaining == 0 then
                --------------------------------------------------------------------------------
                -- Each message starts with an integer value indicating the number of bytes
                -- to follow. We don't have any bytes left to read of a previous message,
                -- so this must be the first 4 bytes:
                --------------------------------------------------------------------------------
                mod._readBytesRemaining = byteStringToNumber(data, 1, 4)
                timer.doAfter(mod.interval, function() mod._socket:read(mod._readBytesRemaining) end)
            else
                --------------------------------------------------------------------------------
                -- We've read the rest of series of commands:
                --------------------------------------------------------------------------------
                mod._readBytesRemaining = 0
                separateHubCommands(data)

                --------------------------------------------------------------------------------
                -- Get set up for the next series of commands:
                --------------------------------------------------------------------------------
                timer.doAfter(mod.interval, function() mod._socket:read(4) end)
            end
        end)
        :connect(mod.ipAddress, mod.port, function()
            --------------------------------------------------------------------------------
            -- Trigger Callback when connected:
            --------------------------------------------------------------------------------
            if mod._callback then
                mod._callback("CONNECTED", {})
            end

            --------------------------------------------------------------------------------
            -- Read the first 4 bytes, which will trigger the callback:
            --------------------------------------------------------------------------------
            mod._socket:read(4)
        end)

    return mod._socket ~= nil or nil

end

return mod