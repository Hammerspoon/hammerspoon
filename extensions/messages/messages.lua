--- === hs.messages ===
---
--- Send messages via iMessage and SMS Relay (note, SMS Relay requires OS X 10.10 and an established SMS Relay pairing between your Mac and an iPhone running iOS8)
---
--- Note: This extension works by controlling the OS X "Messages" app via AppleScript, so you will need that app to be signed into an iMessage account

local messages = {}

local as = require "hs.applescript"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "Messages" to ' .. cmd
  local _, result = as.applescript(_cmd)
  return result
end

--- hs.messages.iMessage(targetAddress, message)
--- Function
--- Sends an iMessage
---
--- Parameters:
---  * targetAddress - A string containing a phone number or email address registered with iMessage, to send the iMessage to
---  * message - A string containing the message to send
---
--- Returns:
---  * None
function messages.iMessage(targetAddress, message)
  tell('send "'..message..'" to buddy "'..targetAddress..'" of (service 1 whose service type is iMessage)')
end
--
--- hs.messages.SMS(targetNumber, message)
--- Function
--- Sends an SMS using SMS Relay
---
--- Parameters:
---  * targetNumber - A string containing a phone number to send an SMS to
---  * message - A string containing the message to send
---
--- Returns:
---  * None
function messages.SMS(targetNumber, message)
  tell('send "'..message..'" to buddy "'..targetNumber..'" of service "SMS"')
end

return messages
