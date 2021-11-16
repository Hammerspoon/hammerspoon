
--- === hs.bonjour ===
---
--- Find and publish network services advertised by multicast DNS (Bonjour) with Hammerspoon.
---
--- This module will allow you to discover services advertised on your network through multicast DNS and publish services offered by your computer.

--- === hs.bonjour.service ===
---
--- Represents the service records that are discovered or published by the hs.bonjour module.
---
--- This module allows you to explore the details of discovered services including ip addresses and text records, and to publish your own multicast DNS advertisements for services on your computer. This can be useful to advertise network services provided by other Hammerspoon modules or other applications on your computer which do not publish their own advertisements already.
---
--- This module will *not* allow you to publish proxy records for other hosts on your local network.
--- Additional submodules which may address this limitation as well as provide additional functions available with Apple's dns-sd library are being considered but there is no estimated timeframe at present.

local USERDATA_TAG = "hs.bonjour"
local module       = require("hs.libbonjour")
module.service     = require("hs.libbonjourservice")

local browserMT = hs.getObjectMetatable(USERDATA_TAG)
-- local serviceMT = hs.getObjectMetatable(USERDATA_TAG .. ".service")

require "hs.doc".registerJSONFile(hs.processInfo["resourcePath"] .. "/docs.json")

local collectionPrevention = {}
local task    = require("hs.task")
local host    = require("hs.host")
local fnutils = require("hs.fnutils")
local timer   = require("hs.timer")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- currently, except for _services._dns-sd._udp., these should be limited to 2 parts, but
-- since one exception exists, let's be open to more in the future
local validateServiceFormat = function(service)
    -- first test: is it a string?
    local isValid = (type(service) == "string")

    -- does it end with _tcp or _udp (with an optional trailing period?)
    if isValid then
        isValid = (service:match("_[uU][dD][pP]%.?$") or service:match("_[tT][cC][pP]%.?$")) and true or false
    end

    -- does each component separated by a period start with an underscore?
    if isValid then
        for part in service:gmatch("([^.]*)%.") do
            isValid = (part:sub(1,1) == "_") and (#part > 1)
            if not isValid then break end
        end
    end

    -- finally, make sure there are at least two parts to the service type
    if isValid then
        isValid = service:match("%g%.%g") and true or false
    end

    return isValid
end

-- Public interface ------------------------------------------------------

--- hs.bonjour:findServices(type, [domain], [callback]) -> browserObject
--- Method
--- Find advertised services of the type specified.
---
--- Parameters:
---  * `type`     - a string specifying the type of service to discover on your network. This string should be specified in the format of '_service._protocol.' where _protocol is one of '_tcp' or '_udp'. Examples of common service types can be found in [hs.bonjour.serviceTypes](#serviceTypes).
---  * `domain`   - an optional string specifying the domain to look for advertised services in. The domain should end with a period. If you omit this parameter, the default registration domain will be used, usually "local."
---  * `callback` - a callback function which will be invoked as service advertisements meeting the specified criteria are discovered. The callback function should expect 2-5 arguments as follows:
---    * if a service is discovered or advertising for the service is terminated, the arguments will be:
---      * the browserObject
---      * the string "domain"
---      * a boolean indicating whether the service is being advertised (true) or should be removed because advertisments for the service are being terminated (false)
---      * the serviceObject for the specific advertisement (see `hs.bonjour.service`)
---      * a boolean indicating if more advertisements are expected (true) or if the macOS believes that there are no more advertisements to be discovered (false).
---    * if an error occurs, the callback arguments will be:
---      * the browserObject
---      * the string "error"
---      * a string specifying the specific error that occurred
---
--- Returns:
---  * the browserObject
---
--- Notes:
---  * macOS will indicate when it believes there are no more advertisements of the type specified by `type` in `domain` by marking the last argument to your callback function as false. This is a best guess and may not always be accurate if your network is slow or some servers on your network are particularly slow to respond.
---  * In addition, if you leave the browser running this method, you will get future updates when services are removed because of server shutdowns or added because of new servers being booted up.
---  * Leaving the browser running does consume some system resources though, so you will have to determine, based upon your specific requirements, if this is a concern for your specific task or not. To terminate the browser when you have rtrieved all of the infomration you reuqire, you can use the [hs.bonjour:stop](#stop) method.
---
---  * The special type "_services._dns-sd._udp." can be used to discover the types of services being advertised on your network. The `hs.bonjour.service` objects returned to the callback function cannot actually be resolved, but you can use the `hs.bonjour.service:name` method to create a list of services that are currently present and being advertised.
---    * this special type is used by the shortcut function [hs.bonjour.networkServices](#networkServices) for this specific purpose.
---
---  * The special domain "dns-sd.org." can be specified to find services advertised through Wide-Area Service Discovery as described at http://www.dns-sd.org. This can be used to discover a limited number of globally available sites on the internet, especially with a service type of `_http._tcp.`.
---    * In theory, with additional software, you may be able to publish services on your machine for Wide-Area Service discovery using this domain with `hs.bonjour.service.new` but the local dns server requirements and security implications of doing so are beyond the scope of this documentation. You should refer to http://www.dns-sd.org and your local DNS Server administrator or provider for more details.
browserMT._browserFindServices = browserMT.findServices
browserMT.findServices = function(self, ...)
    local args = table.pack(...)
    if args.n > 0 and type(args[1]) == "string" then
        if not validateServiceFormat(args[1]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return self:_browserFindServices(...)
end

--- hs.bonjour.service.new(name, service, port, [domain]) -> serviceObject
--- Constructor
--- Returns a new serviceObject for advertising a service provided by your computer.
---
--- Parameters:
---  * `name`    - The name of the service being advertised. This does not have to be the hostname of the machine. However, if you specify an empty string, the computers hostname will be used.
---  * `service` - a string specifying the service being advertised. This string should be specified in the format of '_service._protocol.' where _protocol is one of '_tcp' or '_udp'. Examples of common service types can be found in `hs.bonjour.serviceTypes`.
---  * `port`    - an integer specifying the tcp or udp port the service is provided at
---  * `domain`  - an optional string specifying the domain you wish to advertise this service in.
---
--- Returns:
---  * the newly created service object, or nil if there was an error
---
--- Notes:
---  * If the name specified is not unique on the network for the service type specified, then a number will be appended to the end of the name. This behavior cannot be overridden and can only be detected by checking [hs.bonjour.service:name](#name) after [hs.bonjour.service:publish](#publish) is invoked to see if the name has been changed from what you originally assigned.
---
---  * The service will not be advertised until [hs.bonjour.service:publish](#publish) is invoked on the serviceObject returned.
---
---  * If you do not specify the `domain` paramter, your default domain, usually "local" will be used.
module.service._new = module.service.new
module.service.new = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return module.service._new(...)
end

--- hs.bonjour.service.remote(name, service, [domain]) -> serviceObject
--- Constructor
--- Returns a new serviceObject for a remote machine (i.e. not the users computer) on your network offering the specified service.
---
--- Parameters:
---  * `name`    - a string specifying the name of the advertised service on the network to locate. Often, but not always, this will be the hostname of the machine providing the desired service.
---  * `service` - a string specifying the service type. This string should be specified in the format of '_service._protocol.' where _protocol is one of '_tcp' or '_udp'. Examples of common service types can be found in `hs.bonjour.serviceTypes`.
---  * `domain`  - an optional string specifying the domain the service belongs to.
---
--- Returns:
---  * the newly created service object, or nil if there was an error
---
--- Notes:
---  * In general you should not need to use this constructor, as they will be created automatically for you in the callbacks to `hs.bonjour:findServices`.
---  * This method can be used, however, when you already know that a specific service should exist on the network and you wish to resolve its current IP addresses or text records.
---
---  * Resolution of the service ip address, hostname, port, and current text records will not occur until [hs.bonjour.service:publish](#publish) is invoked on the serviceObject returned.
---
---  * The macOS API specifies that an empty domain string (i.e. specifying the `domain` parameter as "" or leaving it off completely) should result in using the default domain for the computer; in my experience this results in an error when attempting to resolve the serviceObject's ip addresses if I don't specify "local" explicitely. In general this shouldn't be an issue if you limit your use of remote serviceObjects to those returned by `hs.bonjour:findServices` as the domain of discovery will be included in the object for you automatically. If you do try to create these objects independantly yourself, be aware that attempting to use the "default domain" rather than specifying it explicitely will probably not work as expected.
module.service._remote = module.service.remote
module.service.remote = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return module.service._remote(...)
end

--- hs.bonjour.networkServices(callback, [timeout]) -> none
--- Function
--- Returns a list of service types being advertised on your local network.
---
--- Parameters:
---  * `callback` - a callback function which will be invoked when the services query has completed. The callback should expect one argument: an array of strings specifying the service types discovered on the local network.
---  * `timeout`  - an optional number, default 5, specifying the maximum number of seconds after the most recently received service type Hammerspoon should wait trying to identify advertised service types before finishing its query and invoking the callback.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is a convienence wrapper to [hs.bonjour:findServices](#findServices) which collects the results from multiple callbacks made to `findServices` and returns them all at once to the callback function provided as an argument to this function.
---
---  * Because this function collects the results of multiple callbacks before invoking its own callback, the `timeout` value specified indicates the maximum number of seconds to wait after the latest value received by `findServices` unless the macOS specifies that it believes there are no more service types to identify.
---    * This is a best guess made by the macOS which may not always be accurate if your local network is particularly slow or if there are machines on your network which are slow to respond.
---    * See [hs.bonjour:findServices](#findServices) for more details if you need to create your own query which can persist for longer periods of time or require termination logic that ignores the macOS's best guess.
module.networkServices = function(callback, timeout)
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 1")
    if (timeout) then assert(type(timeout) == "number", "number expected for optional argument 2") end
    timeout = timeout or 5

    local uuid = host.uuid()
    local job = module.new()
    collectionPrevention[uuid] = { job = job, results = {} }
    job:findServices("_services._dns-sd._udp.", "local", function(b, msg, state, obj, more) -- luacheck: ignore
        local internals = collectionPrevention[uuid]
        if msg == "service" and state then
            table.insert(internals.results, obj:name() .. "." .. obj:type():match("^(.+)local%.$"))
            if internals.timer then
                internals.timer:stop()
                internals.timer = nil
            end
            if not more then
                internals.timer = timer.doAfter(timeout, function()
                    internals.job:stop()
                    internals.job = nil
                    internals.timer = nil
                    collectionPrevention[uuid] = nil
                    callback(internals.results)
                end)
            end
        end
    end)
end

--- hs.bonjour.machineServices(target, callback) -> none
--- Function
--- Polls a host for the service types it is advertising via multicast DNS.
---
--- Parameters:
---  * `target`   - a string specifying the target host to query for advertised service types
---  * `callback` - a callback function which will be invoked when the service type query has completed. The callback should expect one argument which will either be an array of strings specifying the service types the target is advertising or a string specifying the error that occurred.
---
--- Returns:
---  * None
---
--- Notes:
---  * this function may not work for all clients implementing multicast DNS; it has been successfully tested with macOS and Linux targets running the Avahi Daemon service, but has generally returned an error when used with minimalist implementations found in common IOT devices and embedded electronics.
module.machineServices = function(target, callback)
    assert(type(target) == "string", "string expected for argument 1")
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 2")

    local uuid = host.uuid()
    local job = task.new("/usr/bin/dig", function(r, o, e)
        local results
        if r == 0 then
            results = {}
            for _, v in ipairs(fnutils.split(o, "[\r\n]+")) do
                table.insert(results, v:match("^(.+)local%.$"))
            end
        else
            results = (e == "" and o or e):match("^[^ ]+ (.+)$"):gsub("[\r\n]", "")
        end
        collectionPrevention[uuid] = nil
        callback(results)
    end, { "+short", "_services._dns-sd._udp.local", "ptr", "@" .. target, "-p", "5353" })
    collectionPrevention[uuid] = job:start()
end

--- hs.bonjour.serviceTypes
--- Constant
--- A list of common service types which can used for discovery through this module.
---
--- Notes:
---  * This list was generated from the output of `avahi-browse -b` and `avahi-browse -bk` from the avahi-daemon/stable,now 0.7-4+b1 armhf package under Raspbian GNU/Linux 10.
---  * This list is by no means complete and is provided solely for the purposes of providing examples. Additional service types can be discovered quite easily using Google or other search engines.
---
---  * You can view the contents of this table in the Hammerspoon Console by entering `require("hs.bonjour").serviceTypes` into the input field.
module.serviceTypes = ls.makeConstantsTable({
    ["PulseAudio Sound Server"]                     = "_pulse-server._tcp.",
    ["PostgreSQL Server"]                           = "_postgresql._tcp.",
    ["Apple TimeMachine"]                           = "_adisk._tcp.",
    ["WebDAV File Share"]                           = "_webdav._tcp.",
    ["Timbuktu Remote Desktop Control"]             = "_timbuktu._tcp.",
    ["Adobe Acrobat"]                               = "_acrobatSRV._tcp.",
    ["VNC Remote Access"]                           = "_rfb._tcp.",
    ["Workstation"]                                 = "_workstation._tcp.",
    ["Digital Photo Sharing"]                       = "_dpap._tcp.",
    ["Mumble Server"]                               = "_mumble._tcp.",
    ["APT Package Repository"]                      = "_apt._tcp.",
    ["Virtual Machine Manager"]                     = "_libvirt._tcp.",
    ["SSH Remote Terminal"]                         = "_ssh._tcp.",
    ["Subversion Revision Control"]                 = "_svn._tcp.",
    ["Telnet Remote Terminal"]                      = "_telnet._tcp.",
    ["IMAP Mail Access"]                            = "_imap._tcp.",
    ["RTP Realtime Streaming Server"]               = "_rtp._udp.",
    ["Secure WebDAV File Share"]                    = "_webdavs._tcp.",
    ["iTunes Remote Control"]                       = "_dacp._tcp.",
    ["Apple AirPort"]                               = "_airport._tcp.",
    ["UNIX Printer"]                                = "_printer._tcp.",
    ["SFTP File Transfer"]                          = "_sftp-ssh._tcp.",
    ["DVD or CD Sharing"]                           = "_odisk._tcp.",
    ["Remote Disk Management"]                      = "_udisks-ssh._tcp.",
    ["iChat Presence"]                              = "_presence._tcp.",
    ["POP3 Mail Access"]                            = "_pop3._tcp.",
    ["Asterisk Exchange"]                           = "_iax._udp.",
    ["Web Syndication RSS"]                         = "_rss._tcp.",
    ["Xpra Session Server"]                         = "_xpra._tcp.",
    ["Adobe Version Cue"]                           = "_adobe-vc._tcp.",
    ["Window Shifter"]                              = "_shifter._tcp.",
    ["PDL Printer"]                                 = "_pdl-datastream._tcp.",
    ["Apple Home Sharing"]                          = "_home-sharing._tcp.",
    ["DNS Server"]                                  = "_domain._udp.",
    ["Microsoft Windows Network"]                   = "_smb._tcp.",
    ["VLC Streaming"]                               = "_vlc-http._tcp.",
    ["OmniWeb Bookmark Sharing"]                    = "_omni-bookmark._tcp.",
    ["iTunes Audio Access"]                         = "_daap._tcp.",
    ["KDE System Guard"]                            = "_ksysguard._tcp.",
    ["GnuPG/PGP HKP Key Server"]                    = "_pgpkey-hkp._tcp.",
    ["Distributed Compiler"]                        = "_distcc._tcp.",
    ["Bazaar"]                                      = "_bzr._tcp.",
    ["iPod Touch Music Library"]                    = "_touch-able._tcp.",
    ["Secure Internet Printer"]                     = "_ipps._tcp.",
    ["Secure Web Site"]                             = "_https._tcp.",
    ["Web Site"]                                    = "_http._tcp.",
    ["Thousand Parsec Server (Secure HTTP Tunnel)"] = "_tp-https._tcp.",
    ["NTP Time Server"]                             = "_ntp._udp.",
    ["Skype VoIP"]                                  = "_skype._tcp.",
    ["AirTunes Remote Audio"]                       = "_raop._tcp.",
    ["Apple Net Assistant"]                         = "_net-assistant._udp.",
    ["PulseAudio Sound Sink"]                       = "_pulse-sink._tcp.",
    ["Network File System"]                         = "_nfs._tcp.",
    ["H.323 Telephony"]                             = "_h323._tcp.",
    ["OLPC Presence"]                               = "_presence_olpc._tcp.",
    ["Thousand Parsec Server (Secure)"]             = "_tps._tcp.",
    ["RealPlayer Shared Favorites"]                 = "_realplayfavs._tcp.",
    ["RTSP Realtime Streaming Server"]              = "_rtsp._tcp.",
    ["PulseAudio Sound Source"]                     = "_pulse-source._tcp.",
    ["Apple File Sharing"]                          = "_afpovertcp._tcp.",
    ["Remote Jukebox"]                              = "_remote-jukebox._tcp.",
    ["Internet Printer"]                            = "_ipp._tcp.",
    ["TFTP Trivial File Transfer"]                  = "_tftp._udp.",
    ["Music Player Daemon"]                         = "_mpd._tcp.",
    ["Gobby Collaborative Editor Session"]          = "_lobby._tcp.",
    ["Thousand Parsec Server (HTTP Tunnel)"]        = "_tp-http._tcp.",
    ["SIP Telephony"]                               = "_sip._udp.",
    ["LDAP Directory Server"]                       = "_ldap._tcp.",
    ["MacOS X Duplicate Machine Suppression"]       = "_MacOSXDupSuppress._tcp.",
    ["Thousand Parsec Server"]                      = "_tp._tcp.",
    ["FTP File Transfer"]                           = "_ftp._tcp.",
    ["SubEthaEdit Collaborative Text Editor"]       = "_see._tcp.",
    ["Sleep Proxy Server"]                          = "_sleep-proxy._udp.",
    ["Network Scanner"]                             = "_scanner._tcp.",
    ["Remote Audio Output Protocol"]                = "_raop._tcp.",
    ["Google/Chromecast"]                           = "_googlecast._tcp.",
})

-- Return Module Object --------------------------------------------------

return module
