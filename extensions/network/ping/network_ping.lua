
--- === hs.network.ping ===
---
--- This module provides a basic ping function which can test host availability. Ping is a network diagnostic tool commonly found in most operating systems which can be used to test if a route to a specified host exists and if that host is responding to network traffic.

local USERDATA_TAG = "hs.network.ping"
local module       = {}
module.echoRequest = setmetatable(require("hs.libnetworkping"), {
    __call = function(self, ...) return self.echoRequest(...) end
})

local fnutils      = require("hs.fnutils")
local timer        = require("hs.timer")
local inspect      = require("hs.inspect")

local log          = require"hs.logger".new(USERDATA_TAG, "warning")
module.log = log

-- private variables and methods -----------------------------------------

local validClasses = { "any", "IPv4", "IPv6" }

local internals = setmetatable({}, { __mode = "k" })

local basicPingCompletionFunction = function(self)
    -- in case we got here through the cancel method:
    internals[self].allSent = true
    if getmetatable(internals[self].pingTimer) then internals[self].pingTimer:stop() end
    internals[self].pingTimer = nil

    if getmetatable(internals[self].pingObject) then
        internals[self].callback(self, "didFinish")
        -- theoretically a packet could be received out of order, but since we're ending,
        -- clear callback to make sure it can't be invoked again by something in the queue
        internals[self].pingObject:setCallback(nil):stop()
        internals[self].pingObject = nil
        -- use pairs just in case we're missing a sequence number...
        for _, v in pairs(internals[self].timeouts) do
            if getmetatable(v) then v:stop() end
        end
        internals[self].timeouts = {}
    end
end

local basicPingSummary = function(self)
    local packets, results, transmitted, received = self:packets(), "", 0, 0
    local min, max, avg = math.huge, -math.huge, 0
    for _, v in pairs(packets) do
        transmitted = transmitted + 1
        if v.recv then
            received = received + 1
            local rt = v.recv - v.sent
            min = math.min(min, rt)
            max = math.max(max, rt)
            avg = avg + rt
        end
    end
    avg = avg / transmitted
    min, max, avg = min * 1000, max * 1000, avg * 1000
    results = results .. "--- " .. self:server() .. " ping statistics ---\n" ..
            string.format("%d packets transmitted, %d packets received, %.1f packet loss\n",
                transmitted, received, 100.0 * ((transmitted - received) / transmitted)
            ) ..
            string.format("round-trip min/avg/max = %.3f/%.3f/%.3f ms", min, avg, max)
    return results
end

local pingObjectMT
pingObjectMT = {
--- hs.network.ping:pause() -> pingObject | nil
--- Method
--- Pause an in progress ping process.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the ping process is currently active, returns the pingObject; if the process has already completed, returns nil.
    pause = function(self)
        if getmetatable(internals[self].pingTimer) then
            internals[self].paused = true
            return self
        else
            return nil
        end
    end,

--- hs.network.ping:resume() -> pingObject | nil
--- Method
--- Resume an in progress ping process, if it has been paused.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the ping process is currently active, returns the pingObject; if the process has already completed, returns nil.
    resume = function(self)
        if getmetatable(internals[self].pingTimer) then
            internals[self].paused = nil
            return self
        else
            return nil
        end
    end,

--- hs.network.ping:count([count]) -> integer | pingObject | nil
--- Method
--- Get or set the number of ICMP Echo Requests that will be sent by the ping process
---
--- Parameters:
---  * `count` - an optional integer specifying the total number of echo requests that the ping process should send. If specified, this number must be greater than the number of requests already sent.
---
--- Returns:
---  * if no argument is specified, returns the current number of echo requests the ping process will send; if an argument is specified and the ping process has not completed, returns the pingObject; if the ping process has already completed, then this method returns nil.
    count = function(self, num)
        if type(num) == "nil" then
            return internals[self].maxCount
        elseif getmetatable(internals[self].pingTimer) then
            if math.type(num) == "integer" and num > internals[self].sentCount then
                internals[self].maxCount = num
                internals[self].allSent = false
                return self
            else
                error(string.format("must be an integer > %d", internals[self].sentCount), 2)
            end
        else
            return nil
        end
    end,

--- hs.network.ping:sent() -> integer
--- Method
--- Returns the number of ICMP Echo Requests which have been sent.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The number of echo requests which have been sent so far.
    sent = function(self)
        return internals[self].sentCount
    end,

--- hs.network.ping:server() -> string
--- Method
--- Returns the hostname or ip address string given to the [hs.network.ping.ping](#ping) constructor.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string matching the hostname or ip address given to the [hs.network.ping.ping](#ping) constructor for this object.
    server = function(self)
        return internals[self].hostname
    end,

--- hs.network.ping:isRunning() -> boolean
--- Method
--- Returns whether or not the ping process is currently active.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean indicating if the ping process is active (true) or not (false)
---
--- Notes:
---  * This method will return false only if the ping process has finished sending all echo requests or if it has been cancelled with [hs.network.ping:cancel](#cancel).  To determine if the process is currently sending out echo requests, see [hs.network.ping:isPaused](#isPaused).
    isRunning = function(self)
        return not internals[self].allSent
    end,

--- hs.network.ping:isPaused() -> boolean
--- Method
--- Returns whether or not the ping process is currently paused.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean indicating if the ping process is paused (true) or not (false)
    isPaused = function(self)
        return internals[self].paused or false -- force nil to return false
    end,

--- hs.network.ping:address() -> string
--- Method
--- Returns a string containing the resolved IPv4 or IPv6 address this pingObject is sending echo requests to.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the IPv4 or IPv6 address this pingObject is sending echo requests to or "<unresolved address>" if the address cannot be resolved.
    address = function(self)
        return internals[self].address
    end,

--- hs.network.ping:packets([sequenceNumber]) -> table
--- Method
--- Returns a table containing information about the ICMP Echo packets sent by this pingObject.
---
--- Parameters:
---  * `sequenceNumber` - an optional integer specifying the sequence number of the ICMP Echo packet to return information about.
---
--- Returns:
---  * If `sequenceNumber` is specified, returns a table with key-value pairs containing information about the specific ICMP Echo packet with that sequence number, or an empty table if no packet with that sequence number has been sent yet. If no sequence number is specified, returns an array table of all ICMP Echo packets this object has sent.
---
--- Notes:
---  * Sequence numbers start at 0 while Lua array tables are indexed starting at 1. If you do not specify a `sequenceNumber` to this method, index 1 of the array table returned will contain a table describing the ICMP Echo packet with sequence number 0, index 2 will describe the ICMP Echo packet with sequence number 1, etc.
---
---  * An ICMP Echo packet table will have the following key-value pairs:
---    * `sent`           - a number specifying the time at which the echo request for this packet was sent. This number is the number of seconds since January 1, 1970 at midnight, GMT, and is a floating point number, so you should use `math.floor` on this number before using it as an argument to Lua's `os.date` function.
---    * `recv`           - a number specifying the time at which the echo reply for this packet was received. This number is the number of seconds since January 1, 1970 at midnight, GMT, and is a floating point number, so you should use `math.floor` on this number before using it as an argument to Lua's `os.date` function.
---    * `icmp`           - a table provided by the `hs.network.ping.echoRequest` object which contains the details about the specific ICMP packet this entry corresponds to. It will contain the following keys:
---      * `checksum`       - The ICMP packet checksum used to ensure data integrity.
---      * `code`           - ICMP Control Message Code. Should always be 0.
---      * `identifier`     - The ICMP Identifier generated internally for matching request and reply packets.
---      * `payload`        - A string containing the ICMP payload for this packet. This has been constructed to cause the ICMP packet to be exactly 64 bytes to match the convention for ICMP Echo Requests.
---      * `sequenceNumber` - The ICMP Sequence Number for this packet.
---      * `type`           - ICMP Control Message Type. For ICMPv4, this will be 0 if a reply has been received or 8 no reply has been received yet. For ICMPv6, this will be 129 if a reply has been received or 128 if no reply has been received yet.
---      * `_raw`           - A string containing the ICMP packet as raw data.
    packets = function(self, sequence)
        if sequence then
            return internals[self].packets[sequence + 1] or {}
        else
            return internals[self].packets
        end
    end,

--- hs.network.ping:summary() -> string
--- Method
--- Returns a string containing summary information about the ping process.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a summary string for the current state of the ping process
---
--- Notes:
---  * The summary string will look similar to the following:
--- ~~~
--- --- hostname ping statistics ---
--- 5 packets transmitted, 5 packets received, 0.0 packet loss
--- round-trip min/avg/max = 2.282/4.133/4.926 ms
--- ~~~
---  * The numer of packets received will match the number that has currently been sent, not necessarily the value returned by [hs.network.ping:count](#count).
    summary = basicPingSummary,

--- hs.network.ping:cancel() -> none
--- Method
--- Cancels an in progress ping process, terminating it immediately
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * the `didFinish` message will be sent to the callback function as its final message.
    cancel  = basicPingCompletionFunction,

--- hs.network.ping:setCallback(fn) -> pingObject
--- Method
--- Set or remoce the callback function for the pingObject.
---
--- Parameters:
---  * `fn` - the function to set as the callback, or nil if you wish use the default callback.
---
--- Returns:
---  * the pingObject
---
--- Notes:
---  * Because the ping process begins immediately upon creation with the [hs.network.ping.ping](#ping) constructor, it is preferable to assign the callback with the constructor itself.
---  * This method is provided as a means of changing the callback based on other events (a change in the current network or location, perhaps.)
---  * If you truly wish to create a pingObject with no callback, you will need to do something like `hs.network.ping.ping(...):setCallback(function() end)`.
    setCallback = function(self, ...)
        -- sigh, the only way to check for an explicit nil
        local args = table.pack(...)
        if args.n == 1 then
            local fn = args[1]
            if (getmetatable(fn) or {}).__call or type(fn) == "function" then
                internals[self].callback = fn
            elseif type(fn) == "nil" then
                internals[self].callback = module._defaultCallback
            else
                error("expeected a function or nil, found " .. type(fn), 2)
            end
        else
            error("expected 1 argument, found " .. tostring(args.n), 2)
        end
        return self
    end,

-- mimic traditional userdata metatable fields so this can be used from C if a need arises
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
    __index = function(_, key)
        return pingObjectMT[key] or nil
    end,
    __tostring = function(self)
        return string.format("%s: %s (%s)", USERDATA_TAG, internals[self].hostname, internals[self].label)
    end,
}

local _defaultCallback = function(self, msg, ...)
    if msg == "didStart" then
        print("PING: " .. self:server() .. " (" .. self:address() .. "):")
    elseif msg == "didFail" then
        local err = ...
        print("PING: " .. self:address() .. " error: " .. err)
        print(basicPingSummary(self))
    elseif msg == "sendPacketFailed" then
        local seq, err = ...
        local singleStat = self:packets(seq)
        print(string.format("%d bytes to   %s: icmp_seq=%d %s.",
            #singleStat.icmp._raw,
            self:address(),
            singleStat.icmp.sequenceNumber,
            err
        ))
    elseif msg == "receivedPacket" then
        local seq = ...
        local singleStat = self:packets(seq)
        print(string.format("%d bytes from %s: icmp_seq=%d time=%.3f ms",
            #singleStat.icmp._raw,
            self:address(),
            singleStat.icmp.sequenceNumber,
            (singleStat.recv - singleStat.sent) * 1000
        ))
    elseif msg == "didFinish" then
        print(basicPingSummary(self))
    end
end

-- Public interface ------------------------------------------------------

--- hs.network.ping.ping(server, [count], [interval], [timeout], [class], [fn]) -> pingObject
--- Constructor
--- Test server availability by pinging it with ICMP Echo Requests.
---
--- Parameters:
---  * `server`   - a string containing the hostname or ip address of the server to test. Both IPv4 and IPv6 addresses are supported.
---  * `count`    - an optional integer, default 5, specifying the number of ICMP Echo Requests to send to the server.
---  * `interval` - an optional number, default 1.0, in seconds specifying the delay between the sending of each echo request. To set this parameter, you must supply `count` as well.
---  * `timeout`  - an optional number, default 2.0, in seconds specifying how long before an echo reply is considered to have timed-out. To set this parameter, you must supply `count` and `interval` as well.
---  * `class`    - an optional string, default "any", specifying whether IPv4 or IPv6 should be used to send the ICMP packets. The string must be one of the following:
---    * `any`  - uses the IP version which corresponds to the first address the `server` resolves to
---    * `IPv4` - use IPv4; if `server` cannot resolve to an IPv4 address, or if IPv4 traffic is not supported on the network, the ping will fail with an error.
---    * `IPv6` - use IPv6; if `server` cannot resolve to an IPv6 address, or if IPv6 traffic is not supported on the network, the ping will fail with an error.
---  * `fn`       - the callback function which receives update messages for the ping process. See the Notes for details regarding the callback function.
---
--- Returns:
---  * a pingObject
---
--- Notes:
---  * For convenience, you can call this constructor as `hs.network.ping(server, ...)`
---  * the full ping process will take at most `count` * `interval` + `timeout` seconds from `didStart` to `didFinish`.
---
---  * the default callback function, if `fn` is not specified, prints the results of each echo reply as they are received to the Hammerspoon console and a summary once completed. The output should be familiar to anyone who has used `ping` from the command line.
---
---  * If you provide your own callback function, it should expect between 2 and 4 arguments and return none. The possible arguments which are sent will be one of the following:
---
---    * "didStart" - indicates that address resolution has completed and the ping will begin sending ICMP Echo Requests.
---      * `object`  - the ping object the callback is for
---      * `message` - the message to the callback, in this case "didStart"
---
---    * "didFail" - indicates that the ping process has failed, most likely due to a failure in address resolution or because the network connection has dropped.
---      * `object`  - the ping object the callback is for
---      * `message` - the message to the callback, in this case "didFail"
---      * `error`   - a string containing the error message that has occurred
---
---    * "sendPacketFailed" - indicates that a specific ICMP Echo Request has failed for some reason.
---      * `object`         - the ping object the callback is for
---      * `message`        - the message to the callback, in this case "sendPacketFailed"
---      * `sequenceNumber` - the sequence number of the ICMP packet which has failed to send
---      * `error`          - a string containing the error message that has occurred
---
---    * "receivedPacket" - indicates that an ICMP Echo Request has received the expected ICMP Echo Reply
---      * `object`         - the ping object the callback is for
---      * `message`        - the message to the callback, in this case "receivedPacket"
---      * `sequenceNumber` - the sequence number of the ICMP packet received
---
---    * "didFinish" - indicates that the ping has finished sending all ICMP Echo Requests or has been cancelled
---      * `object`  - the ping object the callback is for
---      * `message` - the message to the callback, in this case "didFinish"
module.ping = function(server, ...)
    assert(type(server) == "string", "server must be a string")
    local count, interval, timeout, class, fn = 5, 1, 2, "any", module._defaultCallback

    local args = table.pack(...)
    local seenCount, seenInterval, seenTimeout, seenClass, seenFn = false, false, false, false
    while #args > 0 do
        local this = table.remove(args, 1)
        if type(this) == "number" then
            if not seenCount then
                count = this
                assert(math.type(count) == "integer" and count > 0, "count must be an integer > 0")
                seenCount = true
            elseif not seenInterval then
                interval = this
                assert(type(interval) == "number" and interval > 0, "interval must be a number > 0")
                seenInterval = true
            elseif not seenTimeout then
                timeout = this
                assert(type(timeout) == "number" and timeout > 0, "timeout must be a number > 0")
                seenTimeout = true
            else
                error("unexpected numerical argument", 2)
            end
        elseif type(this) == "string" then
            if not seenClass then
                class = this
                assert(fnutils.contains(validClasses, class),
                    "class must be one of '" .. table.concat(validClasses, "', '") .. "'")
                seenClass = true
            else
                error("unexpected string argument", 2)
            end
    -- this also allows a table or userdata with a __call metamethod to be considered a function
        elseif (getmetatable(this) or {}).__call or type(this) == "function" then
            if not seenFn then
                fn = this
                seenFn = true
            else
                error("unexpected function argument", 2)
            end
        else
            error("unexpected " .. type(this) .. " argument", 2)
        end
    end

    local self = { "placeholder for pingObject" }
    internals[self] = {
        packets   = {},
        hostname  = server,
        address   = "<unresolved address>",
        allSent   = false,
        callback  = fn,
        label     = tostring(self):match("^table: (.+)$"),
        sentCount = 0,
        maxCount  = count,
        timeouts  = {},
    }

    internals[self].pingObject = module.echoRequest(server):acceptAddressFamily(class):setCallback(function(obj, msg, ...)
        if msg == "didStart" then
            local address = ...
            internals[self].address = address
            internals[self].callback(self, msg)
        elseif msg == "didFail" then
            local err = ...
            if getmetatable(internals[self].pingTimer) then internals[self].pingTimer:stop() end
            internals[self].pingTimer = nil
            -- we don't have to stop because the fail callback has already done it for us
            internals[self].pingObject = nil
            internals[self].callback(self, msg, err)
        elseif msg == "sendPacket" then
            local icmp, seq = ...
            internals[self].packets[seq + 1] = {
                sent           = timer.secondsSinceEpoch(),
                icmp           = icmp,
            }
            internals[self].timeouts[seq + 1] = timer.doAfter(timeout, function()
                internals[self].packets[seq + 1].err = "packet timeout exceeded"
                internals[self].timeouts[seq + 1] = nil
                if internals[self].allSent then basicPingCompletionFunction(self) end
            end)
            -- no callback in simplified version
        elseif msg == "sendPacketFailed" then
            local icmp, seq, err = ...
            internals[self].packets[seq + 1] = {
                sent = timer.secondsSinceEpoch(),
                err  = err,
                icmp = icmp,
            }
            internals[self].callback(self, msg, seq, err)
        elseif msg == "receivedPacket" then
            local icmp, seq = ...
            internals[self].packets[seq + 1].recv = timer.secondsSinceEpoch()
            internals[self].packets[seq + 1].icmp = icmp
            internals[self].packets[seq + 1].err  = nil -- in case a late packet finally arrived
            if getmetatable(internals[self].timeouts[seq + 1]) then
                internals[self].timeouts[seq + 1]:stop()
            end
            internals[self].timeouts[seq + 1] = nil
            internals[self].callback(self, msg, seq)
            if internals[self].allSent then basicPingCompletionFunction(self) end
        elseif msg == "receivedUnexpectedPacket" then
            local icmp = ...
            log.df("unexpected packet when pinging %s:%s", obj:hostName(), (inspect(icmp):gsub("%s+", " ")))
        end
    end):start()
    internals[self].pingTimer  = timer.doEvery(interval, function()
        if not internals[self].paused then
            if internals[self].sentCount < internals[self].maxCount then
                internals[self].pingObject:sendPayload()
                internals[self].sentCount = internals[self].sentCount + 1
                if internals[self].sentCount == internals[self].maxCount then internals[self].allSent = true end
            else
                internals[self].pingTimer:stop()
                internals[self].pingTimer = nil
            end
        end
    end)

    return setmetatable(self, pingObjectMT)
end

-- Return Module Object --------------------------------------------------

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = pingObjectMT

-- allows referring to the default callback as module._defaultCallback here and also supports
-- overriding it  with a new one if we need to for debugging purposes since the lack of a
-- __newindex does not prevent assigning one to the module directly.
setmetatable(module, {
    __index = function(_, key)
        if key == "_defaultCallback" then
            return _defaultCallback
        elseif key == "_internals" then
            return internals
        else
            return nil
        end
    end,
    __call = function(self, ...) return self.ping(...) end,
})

return module
