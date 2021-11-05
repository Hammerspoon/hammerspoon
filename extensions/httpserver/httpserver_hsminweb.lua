
--- === hs.httpserver.hsminweb ===
---
--- Minimalist Web Server for Hammerspoon
---
--- This module aims to be a minimal, but (mostly) standards-compliant web server for use within Hammerspoon.  Expanding upon the Hammerspoon module, `hs.httpserver`, this module adds support for serving static pages stored at a specified document root as well as serving dynamic content from Lua Template Files interpreted within the Hammerspoon environment and external executables which support the CGI/1.1 framework.
---
--- This module aims to provide a fully functional, and somewhat extendable, web server foundation, but will never replace a true dedicated web server application.  Some limitations include:
---  * It is single threaded within the Hammerspoon environment and can only serve one resource at a time
---  * As with all Hammerspoon modules, while dynamic content is being generated, Hammerspoon cannot respond to other callback functions -- a complex or time consuming script may block other Hammerspoon activity in a noticeable manner.
---  * All document requests and responses are handled in memory only -- because of this, maximum resource size is limited to what you are willing to allow Hammerspoon to consume and memory limitations of your computer.
---
--- While some of these limitations may be mitigated to an extent in the future with additional modules and additions to `hs.httpserver`, Hammerspoon's web serving capabilities will never replace a dedicated web server when volume or speed is required.
---
--- An example web site is provided in the `hsdocs` folder of the `hs.doc` module.  This web site can serve documentation for Hammerspoon dynamically generated from the json file included with the Hammerspoon application for internal documentation.  It serves as a basic example of what is possible with this module.
---
--- You can start this web server by typing the following into your Hammerspoon console:
--- `require("hs.doc.hsdocs").start()` and then visiting `http://localhost:12345/` with your web browser.

--   [ ] Wiki docs
--   [ ] Add way to render template (and cgi?) to file
--
--   [ ] document headers._ support table for error functions
--   [ ] document _allowRenderTranslations, _logBadTranslations, and _logPageErrorTranslations
--
-- May see how hard these would be... maybe only for Hammerspoon/Lua Template pages
--   [ ] basic/digest auth via lua only?
--   [ ] minimal WebDAV support?
--   [ ] For WebDav support, some other methods may also require a body... (i.e. additions to hs.httpserver)
--
-- Not until requested/needed
--   [ ] cookie support? other than passing to/from dynamic pages, do we need to do anything?
--   [ ] SSI?  will need a way to verify text content or specific header check
--   [ ] support per-dir, in addition to per-server settings?
--   [ ] should things like directory index code be a function so it can be overridden?
--       [ ] custom headers/footers? (auto include head/tail files if exist?)

local USERDATA_TAG          = "hs.httpserver.hsminweb"
local VERSION               = "0.0.5"

local DEFAULT_ScriptTimeout = 30
local scriptWrapper         = hs.processInfo["resourcePath"].."/timeout3"
local cgiluaCompat          = require("hs.cgilua_compatibility_functions")

local module     = {}

local http       = require("hs.http")
local fs         = require("hs.fs")
local nethost    = require("hs.network.host")
local hshost     = require("hs.host")

local serverAdmin    = os.getenv("USER") .. "@" .. hshost.localizedName()
local serverSoftware = USERDATA_TAG:gsub("^hs%.httpserver%.", "") .. "/" .. VERSION .. " (OSX)"
local log            = require("hs.logger").new(USERDATA_TAG:gsub("^hs%.httpserver%.", ""), "debug")

local HTTPdateFormatString = "!%a, %d %b %Y %T GMT"
local HTTPformattedDate    = function(x) return os.date(HTTPdateFormatString, x or os.time()) end

local shallowCopy = function(t1)
    local t2 = {}
    for k, v in pairs(t1) do t2[k] = v end
    return t2
end

local modifyHeaders = function(headerTbl, modifiersTbl)
    local tmpTable = shallowCopy(headerTbl)
    for k, v in pairs(modifiersTbl) do
        if v then
            tmpTable[k] = v
        else
            tmpTable[k] = nil
        end
    end
    return tmpTable
end

local directoryIndex = {
    "index.html", "index.htm"
}

local cgiExtensions = {
    "cgi", "pl"
}

-- This table is from various sources, including (but probably not limited to):
--    "Official" list at https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
--    KeplerProject's wsapi at https://github.com/keplerproject/wsapi
--    IIS additions from https://support.microsoft.com/en-us/kb/943891
--
-- Actually, only 400+ are error conditions, but this is the complete list for reference
local statusCodes = {
    ["100"] = "Continue",
    ["101"] = "Switching Protocols",
    ["200"] = "OK",
    ["201"] = "Created",
    ["202"] = "Accepted",
    ["203"] = "Non-Authoritative Information",
    ["204"] = "No Content",
    ["205"] = "Reset Content",
    ["206"] = "Partial Content",
    ["300"] = "Multiple Choices",
    ["301"] = "Moved Permanently",
    ["302"] = "Found",
    ["303"] = "See Other",
    ["304"] = "Not Modified",
    ["305"] = "Use Proxy",
    ["307"] = "Temporary Redirect",
    ["400"] = "Bad Request",
      ["400.1"]   = "Invalid Destination Header",
      ["400.2"]   = "Invalid Depth Header",
      ["400.3"]   = "Invalid If Header",
      ["400.4"]   = "Invalid Overwrite Header",
      ["400.5"]   = "Invalid Translate Header",
      ["400.6"]   = "Invalid Request Body",
      ["400.7"]   = "Invalid Content Length",
      ["400.8"]   = "Invalid Timeout",
      ["400.9"]   = "Invalid Lock Token",
      ["400.10"]  = "Invalid XFF header",
      ["400.11"]  = "Invalid WebSocket request",
      ["400.601"] = "Bad client request (ARR)",
      ["400.602"] = "Invalid time format (ARR)",
      ["400.603"] = "Parse range error (ARR)",
      ["400.604"] = "Client gone (ARR)",
      ["400.605"] = "Maximum number of forwards (ARR)",
      ["400.606"] = "Asynchronous competition error (ARR)",
    ["401"] = "Unauthorized",
      ["401.1"] = "Logon failed",
      ["401.2"] = "Logon failed due to server configuration",
      ["401.3"] = "Unauthorized due to ACL on resource",
      ["401.4"] = "Authorization failed by filter",
      ["401.5"] = "Authorization failed by ISAPI/CGI application",
    ["402"] = "Payment Required",
    ["403"] = "Forbidden",
      ["403.1"]   = "Execute access forbidden",
      ["403.2"]   = "Read access forbidden",
      ["403.3"]   = "Write access forbidden",
      ["403.4"]   = "SSL required",
      ["403.5"]   = "SSL 128 required",
      ["403.6"]   = "IP address rejected",
      ["403.7"]   = "Client certificate required",
      ["403.8"]   = "Site access denied",
      ["403.9"]   = "Forbidden: Too many clients are trying to connect to the web server",
      ["403.10"]  = "Forbidden: web server is configured to deny Execute access",
      ["403.11"]  = "Forbidden: Password has been changed",
      ["403.12"]  = "Mapper denied access",
      ["403.13"]  = "Client certificate revoked",
      ["403.14"]  = "Directory listing denied",
      ["403.15"]  = "Forbidden: Client access licenses have exceeded limits on the web server",
      ["403.16"]  = "Client certificate is untrusted or invalid",
      ["403.17"]  = "Client certificate has expired or is not yet valid",
      ["403.18"]  = "Cannot execute requested URL in the current application pool",
      ["403.19"]  = "Cannot execute CGI applications for the client in this application pool",
      ["403.20"]  = "Forbidden: Passport logon failed",
      ["403.21"]  = "Forbidden: Source access denied",
      ["403.22"]  = "Forbidden: Infinite depth is denied",
      ["403.502"] = "Forbidden: Too many requests from the same client IP; Dynamic IP Restriction limit reached",
    ["404"] = "Not Found",
      ["404.0"]  = "Not Found",
      ["404.1"]  = "Site Not Found",
      ["404.2"]  = "ISAPI or CGI restriction",
      ["404.3"]  = "MIME type restriction",
      ["404.4"]  = "No handler configured",
      ["404.5"]  = "Denied by request filtering configuration",
      ["404.6"]  = "Verb denied",
      ["404.7"]  = "File extension denied",
      ["404.8"]  = "Hidden namespace",
      ["404.9"]  = "File attribute hidden",
      ["404.10"] = "Request header too long",
      ["404.11"] = "Request contains double escape sequence",
      ["404.12"] = "Request contains high-bit characters",
      ["404.13"] = "Content length too large",
      ["404.14"] = "Request URL too long",
      ["404.15"] = "Query string too long",
      ["404.16"] = "DAV request sent to the static file handler",
      ["404.17"] = "Dynamic content mapped to the static file handler via a wildcard MIME mapping",
      ["404.18"] = "Querystring sequence denied",
      ["404.19"] = "Denied by filtering rule",
      ["404.20"] = "Too Many URL Segments",
    ["405"] = "Method Not Allowed",
    ["406"] = "Not Acceptable",
    ["407"] = "Proxy Authentication Required",
    ["408"] = "Request Time-out",
    ["409"] = "Conflict",
    ["410"] = "Gone",
    ["411"] = "Length Required",
    ["412"] = "Precondition Failed",
    ["413"] = "Request Entity Too Large",
    ["414"] = "Request-URI Too Large",
    ["415"] = "Unsupported Media Type",
    ["416"] = "Requested range not satisfiable",
    ["417"] = "Expectation Failed",
    ["500"] = "Internal Server Error",
      ["500.0"]   = "Module or ISAPI error occurred",
      ["500.11"]  = "Application is shutting down on the web server",
      ["500.12"]  = "Application is busy restarting on the web server",
      ["500.13"]  = "Web server is too busy",
      ["500.15"]  = "Direct requests for Global.asax are not allowed",
      ["500.19"]  = "Configuration data is invalid",
      ["500.21"]  = "Module not recognized",
      ["500.22"]  = "An ASP.NET httpModules configuration does not apply in Managed Pipeline mode",
      ["500.23"]  = "An ASP.NET httpHandlers configuration does not apply in Managed Pipeline mode",
      ["500.24"]  = "An ASP.NET impersonation configuration does not apply in Managed Pipeline mode",
      ["500.50"]  = "A rewrite error occurred during RQ_BEGIN_REQUEST notification handling",
      ["500.51"]  = "A rewrite error occurred during GL_PRE_BEGIN_REQUEST notification handling",
      ["500.52"]  = "A rewrite error occurred during RQ_SEND_RESPONSE notification handling",
      ["500.53"]  = "A rewrite error occurred during RQ_RELEASE_REQUEST_STATE notification handling",
      ["500.100"] = "Internal ASP error",
    ["501"] = "Not Implemented",
    ["502"] = "Bad Gateway",
      ["502.1"] = "CGI application timeout",
      ["502.2"] = "Bad gateway: Premature Exit",
      ["502.3"] = "Bad Gateway: Forwarder Connection Error (ARR)",
      ["502.4"] = "Bad Gateway: No Server (ARR)",
      ["502.5"] = "WebSocket failure (ARR)",
      ["502.6"] = "Forwarded request failure (ARR)",
      ["502.7"] = "Execute request failure (ARR)",
    ["503"] = "Service Unavailable",
      ["503.0"] = "Application pool unavailable",
      ["503.2"] = "Concurrent request limit exceeded",
      ["503.3"] = "ASP.NET queue full",
    ["504"] = "Gateway Time-out",
    ["505"] = "HTTP Version not supported",
}

local errorHandlers = {
    __index = function(_, key)
        local override = rawget(_, tostring(key))
        if override then
            return override
        elseif rawget(_, "default") then
            return function(...) return  rawget(_, "default")(key, ...) end
        else
            return function(_, _, h)
                local code = key
                if type(code) == "number" then code = tostring(code) end
                local intendedCode = code
                local codeLabel = statusCodes[code]
                if tonumber(code) < 400 or not codeLabel then code, codeLabel = "500", statusCodes["500"] end

                local output = "<html><head><title>" .. codeLabel .. "</title></head><body><body><H1>HTTP/1.1 " .. code .. " " .. codeLabel .. "</H1><br/><br/>"

                if code ~= intendedCode then
                    if tonumber(intendedCode) > 399 then
                        output = output .. "Error code " .. intendedCode .. " is unrecognized and has no handler<br/>"
                    else
                        local statusLabel = statusCodes[intendedCode] or "** Unrecognized Status Code **"
                        output = output .. "Status code ".. intendedCode .. ", " .. statusLabel .. ", does not specify an error condition<br/>"
                    end
                end

                output = output .. "<hr/><div align=\"right\"><i>" .. tostring(h and h._ and h._.serverSoftware) .. " at " .. tostring(h and h._ and h._.queryDate) .. "</i></div></body></html>"

                return output, math.floor(code), (h and h._ and h._.minimalHTMLResponseHeaders or {})
            end
        end
    end
}

local supportedMethods = {
-- https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol
    GET       = true,
    HEAD      = true,
    POST      = true,
    PUT       = false,
    DELETE    = false,
    TRACE     = false,
    OPTIONS   = false,
    CONNECT   = false,
    PATCH     = false,
-- https://en.wikipedia.org/wiki/WebDAV
    PROPFIND  = false,
    PROPPATCH = false,
    MKCOL     = false,
    COPY      = false,
    MOVE      = false,
    LOCK      = false,
    UNLOCK    = false,
}

local textWithLineNumbers = function(theText, lineNum, lineSep)
    lineNum = lineNum or 1
    lineSep = lineSep or ": "
    local max = lineNum
    theText:gsub("\n", function(_) max = max + 1 ; return _ end)
    return string.format("%" .. #tostring(max) .. "d%s%s", lineNum, lineSep, (theText:gsub("\n", function(_) lineNum = lineNum + 1 ; return string.format("%s%" .. #tostring(max) .. "d%s", _, lineNum, lineSep) end)))
end

local objectMethods = {}
local mt_table = {
    __passwords = {},
    __luaCaches = {},
    __tostrings = {},
    __index     = objectMethods,
    __metatable = objectMethods, -- getmetatable should only list the available methods
    __type      = USERDATA_TAG,
}

mt_table.__tostring  = function(_)
    return mt_table.__type .. ": " .. tostring(_:name()) .. ":" .. tostring(_:port()) .. ", " .. (mt_table.__tostrings[_] or "* unbound -- this is unsupported *")
end

local RFC3986getURLParts = function(resourceLocator)
    local parts = {}

    parts["URL"] = resourceLocator
    -- we need to parse the URL to make sure we handle the path part correctly (the OS X internals follow RFC1808, but modern web browsers follow the newer RFC3986, which obsoletes 1808, plus we need the / character on path components to more easily detect when to throw 301; however for resolving .. and ., this is easier than doing it ourselves
    parts["standardizedURL"] = http.urlParts(resourceLocator).standardizedURL

    local stillNeedsParsing = resourceLocator
    local scheme
    if stillNeedsParsing:sub(1,1):match("%w") then
        scheme = stillNeedsParsing:match("^(%w[%w%d%+%-%.]*):"):lower()
        if scheme then stillNeedsParsing = stillNeedsParsing:sub(#scheme + 2) end
    elseif stillNeedsParsing:sub(1,1) == "/" then
        scheme = ""
    end
    if scheme then
        parts["scheme"] = scheme
    else
        error("invalid scheme specified", 3)
    end
    parts["resourceSpecifier"] = stillNeedsParsing

    local authority
    if stillNeedsParsing:sub(1,2) == "//" then
        authority = stillNeedsParsing:match("^//([^/%?#]*)")
        if authority then stillNeedsParsing = stillNeedsParsing:sub(#authority + 3) end
    elseif stillNeedsParsing:sub(1,1):match("[%w/%d_]") then
        authority = ""
    end

    if authority then
        if authority ~= "" then
            local userInfo, hostInfo = authority:match("^(.*)@([^@]*)$") -- last @ separates user:pass@host:port
            if not userInfo then
                userInfo = ""
                hostInfo = authority
            end
            if userInfo ~= "" then
                local user, pass = userInfo:match("^([^:]*):(.*)$") -- first : separates user:pass
                if not user then
                    user = userInfo
                    pass = nil
                end
                parts["user"] = user
                parts["password"] = pass
            end
            if hostInfo ~= "" then
                local host, port = hostInfo:match("^(.*):([^:]*)$") -- last : separates host:port
                if host then
                    port = tonumber(port)
                else
                    host = hostInfo
                    port = nil
                end
                parts["host"] = host
                parts["port"] = port
            end
        end
    else
        error("invalid authority specified", 3)
    end

    local lastPathComponent, path, pathComponents, pathExtension = "", "", {}, ""

    local pathPartOnly, theRest = stillNeedsParsing:match("^([^#%?]*)([#%?]?.*)$")
    if pathPartOnly ~= "" then
        -- unlike internal version used by hs.http.urlParts, keep "/" attached to path components... keeps us from missing lone "/", especially when figuring out PATH_INFO
        for k in pathPartOnly:gmatch("([^/]*/?)") do
            local component = k:gsub("%%[0-9a-fA-F][0-9a-fA-F]", function(val) return string.char(tonumber(val:sub(2,3), 16)) end)
            table.insert(pathComponents, component)
        end
        while (pathComponents[#pathComponents] == "") do table.remove(pathComponents) end
        lastPathComponent = pathComponents[#pathComponents]
        local possibleExtension = lastPathComponent:match("^.*%.([^/]+)/?$")
        if possibleExtension then pathExtension = possibleExtension end
        path              = pathPartOnly:gsub("%%[0-9a-fA-F][0-9a-fA-F]", function(val) return string.char(tonumber(val:sub(2,3), 16)) end)
        stillNeedsParsing = theRest
    end
    parts["lastPathComponent"] = lastPathComponent
    parts["path"]              = path
    parts["pathComponents"]    = pathComponents
    parts["pathExtension"]     = pathExtension

    local query, fragment = stillNeedsParsing:match("^%??([^#]*)(.*)$")
    if query ~= ""   then parts["query"] = query end
    if #fragment > 0 then parts["fragment"] = fragment:sub(2) end

    return parts
end

local verifyAccess = function(aclTable, headers)
    local accessGranted = false
    local headerMap = {}

    -- the dash and the underline get changed so friggen often depending upon context... just make
    -- the access-list comparisons agnostic about them as well as case.

    for k, _ in pairs(headers) do headerMap[k:upper():gsub("-","_")] = k end

    for i, v in ipairs(aclTable) do
        local headerToCheck = v[1]:upper():gsub("-","_")
        local valueToCheck  = v[2]
        local isPattern     = v[3]
        local desiredResult = v[4]

        if type(v[1]) == "string" and
           type(v[2]) == "string" and
           (type(v[3]) == "boolean" or type(v[3]) == "nil") and
           (type(v[4]) == "boolean" or type(v[4]) == "nil") then

            if headerToCheck == '*' and valueToCheck == '*' then
                accessGranted = desiredResult
                break
            else
                local matched = false
                local value = headers[headerMap[headerToCheck]]
                if value then
                    if isPattern then
                        matched = value:match(valueToCheck)
                    else
                        matched = (value == valueToCheck)
                    end
                end
                if matched then
                    accessGranted = desiredResult
                    break
                end
            end
        else
            log.wf("access-list entry %d malformed, found { %s, %s, %s, %s }: skipping", i, type(v[1]), type(v[2]), type(v[3]), type(v[4]))
        end
    end

    return accessGranted
end

local webServerHandler = function(self, method, path, headers, body)
    method = method:upper()

-- Allow some internally determined stuff to be passed around to various support functions
    headers._ = {
        server         = self,
        SSL            = self._ssl and true or false,
        serverAdmin    = self._serverAdmin,
        serverSoftware = serverSoftware,
        pathParts      = RFC3986getURLParts((self._ssl and "https" or "http") .. "://" .. headers.Host .. path),
        modifyHeaders  = modifyHeaders,
        queryDate      = HTTPformattedDate(),
    }

    headers._.minimalResponseHeaders = {
        ["Server"]        = serverSoftware,
        ["Last-Modified"] = headers._.queryDate,
    }
    headers._.minimalHTMLResponseHeaders = modifyHeaders(headers._.minimalResponseHeaders, {
        ["Content-Type"]  = "text/html",
    })

    if self._accessList and not verifyAccess(self._accessList, headers) then
        return self._errorHandlers[403](method, path, headers)
    end

-- Check if the method is supported
    local action = self._supportedMethods[method]
    if not action then return self._errorHandlers[405](method, path, headers) end

-- Figure out what specific file/directory is being requested
    local pathParts  = headers._.pathParts
    local testingPath = self._documentRoot

    -- 301 if no path and no initial "/"... not sure this is necessary since testing with curl has curl fixing this before sending the request, but not sure if all browsers/web-getter-thingies do that or not, so we take care of it jic
    if #pathParts.pathComponents == 0 then
        local newLoc = pathParts.scheme .. "://" .. headers.Host .. "/"
        if pathParts.query    then newLoc = newLoc .. "?" .. pathParts.query end
        if pathParts.fragment then newLoc = newLoc .. "#" .. pathParts.fragment end
        return "", 301, modifyHeaders(headers._.minimalHTMLResponseHeaders, { ["Location"] = newLoc })
    end

    for i = 1, #pathParts.pathComponents, 1 do
        testingPath = testingPath .. pathParts.pathComponents[i]
        local testAttr = fs.attributes(testingPath)
        if not testAttr then testAttr = fs.attributes(testingPath:sub(1, #testingPath - 1)) end
        if testAttr then
            if i ~= #pathParts.pathComponents or (i == #pathParts.pathComponents and testingPath:sub(#testingPath) == "/") then
                if testAttr.mode == "file" then
                    if self._cgiEnabled or self._luaTemplateExtension then
                        local testExtension = pathParts.pathComponents[i]:match("^.*%.([^%.]+)/$") or ""
                        local testIsCGI = false
                        if self._cgiEnabled then
                            for _, v in ipairs(self._cgiExtensions) do
                                if v == testExtension then
                                    testIsCGI = true
                                    break
                                end
                            end
                        end
                        if not testIsCGI and self._luaTemplateExtension then
                            testIsCGI = (self._luaTemplateExtension == testExtension)
                        end

                        if testIsCGI then -- we got a PATH_INFO situation
                            local realPathPart = table.concat(pathParts.pathComponents, "", 1, i)
                            realPathPart = realPathPart:sub(1, #realPathPart - 1)
                            local pathInfoPart = "/" .. table.concat(pathParts.pathComponents, "", i + 1)
                            local newURL = pathParts.scheme .. "://" .. headers.Host .. realPathPart
                            if pathParts.query then newURL = newURL .. "?" .. pathParts.query end
                            if pathParts.fragment then newURL = newURL .. "#" .. pathParts.fragment end
                            headers._.pathParts = RFC3986getURLParts(newURL)
                            pathParts = headers._.pathParts
                            pathParts.pathInfo = pathInfoPart
                            break
                        else -- returning 404 because it's not a cgi file, and thus it's file where a directory should be
                            return self._errorHandlers[404](method, path, headers)
                        end
                    else -- returning 404 because it's a file where a directory should be and cgi is disabled
                        return self._errorHandlers[404](method, path, headers)
                    end
                end -- dir at this point is ok
            else
                if testAttr.mode == "directory" then
                    if pathParts.pathComponents[i]:sub(#pathParts.pathComponents[i]) ~= "/" then
                        -- 301 because last directory component doesn't end with a "/"
                        local newLoc = pathParts.scheme .. "://" .. headers.Host .. pathParts.path .. "/"
                        if pathParts.query    then newLoc = newLoc .. "?" .. pathParts.query end
                        if pathParts.fragment then newLoc = newLoc .. "#" .. pathParts.fragment end
                        return "", 301, modifyHeaders(headers._.minimalHTMLResponseHeaders, { ["Location"] = newLoc })
                    end
                end -- file at this point is ok
            end
        else -- 404 because some component of path doesn't really exist
            return self._errorHandlers[404](method, path, headers)
        end
    end

    local targetFile = self._documentRoot .. pathParts.path

    local attributes = fs.attributes(targetFile)

    -- check if an index file for the directory exists
    if attributes.mode == "directory" and self._directoryIndex then
        for _, v in ipairs(self._directoryIndex) do
            local attr = fs.attributes(targetFile .. v)
            if attr and attr.mode == "file" then
                targetFile = targetFile .. v
                attributes = attr
                local newURL = pathParts.scheme .. "://" .. headers.Host .. pathParts.path .. v
                if pathParts.query then newURL = newURL .. "?" .. pathParts.query end
                if pathParts.fragment then newURL = newURL .. "#" .. pathParts.fragment end
                headers._.pathParts = RFC3986getURLParts(newURL)
                pathParts = headers._.pathParts
                break
            elseif attr then
                log.wf("default directoryIndex %s for %s is not a file; skipping", v, pathParts.standardizedURL)
            end
        end
    end

    -- check extension and see if it's an executable CGI
    local itBeCGI = false
    if pathParts.pathExtension and self._cgiEnabled then
        for _, v in ipairs(self._cgiExtensions) do
            if v == pathParts.pathExtension then
                itBeCGI = true
                break
            end
        end
    end

    local itBeDynamic = itBeCGI or (self._luaTemplateExtension and pathParts.pathExtension and self._luaTemplateExtension == pathParts.pathExtension)

    local responseBody, responseCode, responseHeaders = "", 200, {}

    responseHeaders["Last-Modified"] = HTTPformattedDate(attributes.modified)
    responseHeaders["Server"]        = serverSoftware

    if itBeDynamic then
    -- target is dynamically generated
        responseHeaders["Last-Modified"] = headers._.queryDate

        -- per https://tools.ietf.org/html/rfc3875
        local CGIVariables = {
            AUTH_TYPE         = self:password() and "Basic" or nil,
            CONTENT_TYPE      = headers["Content-Type"],
            CONTENT_LENGTH    = headers["Content-Length"],
            GATEWAY_INTERFACE = "CGI/1.1",
            PATH_INFO         = pathParts.pathInfo,
--             PATH_TRANSLATED   = , -- see below
            QUERY_STRING      = pathParts.query,
            REQUEST_METHOD    = method,
            REQUEST_SCHEME    = pathParts.scheme,
            REMOTE_ADDR       = headers["X-Remote-Addr"],
            REMOTE_PORT       = headers["X-Remote-Port"],
--             REMOTE_HOST       = , -- see below
--             REMOTE_IDENT      = , -- we don't support IDENT protocol
            REMOTE_USER       = self:password() and "" or nil,
            SCRIPT_NAME       = pathParts.path,
            SERVER_ADMIN      = serverAdmin,
            SERVER_NAME       = pathParts.host,
            SERVER_ADDR       = headers["X-Server-Addr"],
            SERVER_PORT       = headers["X-Server-Port"],
            SERVER_PROTOCOL   = "HTTP/1.1",
            SERVER_SOFTWARE   = serverSoftware,
        }

        if CGIVariables.PATH_INFO then
            CGIVariables.PATH_TRANSLATED = self._documentRoot .. CGIVariables.PATH_INFO
        end
        if self._dnsLookup then
            local good, val = pcall(nethost.hostnamesForAddress, CGIVariables.REMOTE_ADDR)
            if good then
                CGIVariables.REMOTE_HOST = val[1]
            else
                log.f("unable to resolve %s", CGIVariables.REMOTE_ADDR)
            end
        end
--         if not CGIVariables.REMOTE_HOST then
--             CGIVariables.REMOTE_HOST = CGIVariables.REMOTE_ADDR
--         end

        -- Request headers per rfc2875
        for k, v in pairs(headers) do
            local k2 = k:upper():gsub("-", "_")
            -- skip Authorization related headers (per rfc2875) and _ internally used table
            if not ({ ["AUTHORIZATION"] = 1, ["PROXY-AUTHORIZATION"] = 1, ["_"] = 1 })[k2] then
                CGIVariables["HTTP_" .. k2] = v
            end
        end

        -- commonly added
        CGIVariables.DOCUMENT_URI    = CGIVariables.SCRIPT_NAME .. (CGIVariables.PATH_INFO or "")
        CGIVariables.REQUEST_URI     = CGIVariables.DOCUMENT_URI .. (CGIVariables.QUERY_STRING and ("?" .. CGIVariables.QUERY_STRING) or "")
        CGIVariables.DOCUMENT_ROOT   = self._documentRoot
        CGIVariables.SCRIPT_FILENAME = targetFile
        CGIVariables.REQUEST_TIME    = os.time()

        if itBeCGI then
        -- do external script thing

-- this is a horrible horrible hack...
-- look for an update to hs.httpserver because I really really really want to use hs.task for this, but we need chunked or delayed response support for that to work...

            local scriptTimeout = self._scriptTimeout or DEFAULT_ScriptTimeout
            local tempFileName = fs.temporaryDirectory() .. "/" .. USERDATA_TAG:gsub("^hs%.httpserver%.", "") .. hshost.globallyUniqueString()

            local tmpCGIFile = io.open(tempFileName, "w")
            tmpCGIFile:write("#! /bin/bash\n\n")
            for k, v in pairs(CGIVariables) do
                tmpCGIFile:write(string.format("export %s=%q\n", k, v))
            end
            tmpCGIFile:write("exec " .. targetFile .. "\n")
            tmpCGIFile:close()
            os.execute("chmod +x " .. tempFileName)

            local tmpInputFile = io.open(tempFileName .. "input", "w")
            tmpInputFile:write(body)
            tmpInputFile:close()

            local targetWD = self._documentRoot .. "/" .. table.concat(pathParts.pathComponents, "", 2, #pathParts.pathComponents - 1)
            local oldWD = fs.currentDir()
            fs.chdir(targetWD)

            local out, stat, typ, rc = hs.execute("/bin/cat " .. tempFileName .. "input | /usr/bin/env -i PATH=\"/usr/bin:/bin:/usr/sbin:/sbin\" " .. scriptWrapper .. " -t " .. tostring(scriptTimeout) .. " " .. tempFileName .. " 2> " .. tempFileName .. "err")

            fs.chdir(oldWD)

            if stat then
                responseCode = 200
                local headerText, bodyText = out:match("^(.-)\r?\n\r?\n(.*)$")
                if headerText then
                    for line in (headerText .. "\n"):gmatch("(.-)\r?\n") do
                        local newKey, newValue = line:match("^(.-):(.*)$")
                        if not newKey then -- malformed header, break out and show everything
                            log.i("malformed header in CGI output")
                            bodyText = out
                            break
                        end
                        if newKey:upper() == "STATUS" then
                            responseCode = newValue:match("(%d+)[^%d]")
                        else
                            responseHeaders[newKey] = newValue
                        end
                    end
                    responseBody = bodyText
                else
                    responseBody = out
                    responseHeaders["Content-Type"] = "text/plain"
                end
            else
                local errOut = "** no stderr **"
                local errf = io.open(tempFileName .. "err", "rb")
                if errf then
                    errOut = errf:read("a")
                    errf:close()
                end
                log.ef("CGI error: output:%s, stderr:%s, %s code:%d", out, errOut, typ, rc)
                log.ef("CGI support files %s* not removed", tempFileName)
                return self._errorHandlers[500](method, path, headers)
            end

            if log.level ~= 5 then -- if we're at verbose, it means we're tracking something down...
                os.execute("rm " .. tempFileName)
                os.execute("rm " .. tempFileName .. "input")
                os.execute("rm " .. tempFileName .. "err")
            else
                log.vf("CGI support files %s* not removed", tempFileName)
            end

        else
            local finput = io.open(targetFile, "rb")
            if not finput then return self._errorHandlers[403.2](method, path, headers) end
            local workingBody = finput:read("a")
            finput:close()
            -- some UTF8 encoded files include the UTF8 BOM (byte order mark) at the beginning of the file, even though this is recommended against for UTF8; lua doesn't like these characters, so remove them if necessary
            if workingBody:sub(1,3) == "\xEF\xBB\xBF" then workingBody = workingBody:sub(4) end

-- decode query and/or body

            -- setup the library of CGILua compatibility functions for the function environment
            local _parent = {
                id           = hshost.globallyUniqueString(),
                log          = log,
                request      = {
                    method  = method,
                    path    = path,
                    headers = headers,
                    body    = body,
                },
                response     = {
                    body    = responseBody,
                    code    = responseCode,
                    headers = modifyHeaders(responseHeaders, {
                                  ["Content-Type"] = "text/html",
                              }),
                },
                CGIVariables = CGIVariables,
                _tmpfiles    = {},
            }

            local M = setmetatable({}, {
                __index = function(_, k)
                    log.wf("CGILua compatibility function %s not implemented, returning nil", k)
                    return nil
                end
            })
            for k, v in pairs(cgiluaCompat) do
                if type(v) == "function" then
                    M[k] = function(...) return v(_parent, ...) end
                elseif type(v) == "table" then
                    M[k] = {}
                    for k2, v2 in pairs(v) do
                        if type(v2) == "function" then
                            M[k][k2] = function(...) return v2(_parent, ...) end
                        else
                            M[k][k2] = v2
                        end
                    end
                else
                    M[k] = v
                end
            end

            -- can't assign in cgilua_compatibility_functions because debug.traceback is a function but it's one we don't want to wrap with a preceding _parent argument
            M._errorhandler = debug.traceback

            -- documentation for these is in the cgilua_compatibility_functions.lua file to keep them logically organized
            M.script_path  = CGIVariables["SCRIPT_FILENAME"]
            M.script_pdir, M.script_file = M.script_path:match("^(.-)([^:/\\]*)$")

            M.script_vpath = CGIVariables["PATH_INFO"] or "/"
            M.script_vdir  = M.script_vpath:match("^(.-)[^:/\\]*$")

            M.urlpath      = CGIVariables["SCRIPT_NAME"]

            M.QUERY = {}
            cgiluaCompat.urlcode.parsequery(_parent, CGIVariables["QUERY_STRING"], M.QUERY)
            M.POST = {}
            if method == "POST" then
                local contentType = CGIVariables["CONTENT_TYPE"]:match("^([^; ]+)")
                if not contentType then
                    log.ef("Missing or malformed CONTENT_TYPE for POST: %s", tostring(CGIVariables["CONTENT_TYPE"]))
                    return self._errorHandlers[400](method, path, headers)
                end
                if contentType == "x-www-form-urlencoded" or contentType == "application/x-www-form-urlencoded" then
                    cgiluaCompat.urlcode.parsequery(_parent, body, M.POST)
                elseif contentType == "multipart/form-data" then
                    local _,_,boundary = CGIVariables["CONTENT_TYPE"]:find("boundary%=(.-)$")
                    boundary = "--" .. boundary
                    -- lua doesn't have a "continue" or "next" operation in for, so we're reduced to this
                    for chunk in body:gmatch("(.-)"..boundary) do repeat
                        if #chunk == 0 then break end -- "continue"

                        local _, ePos, headerdata = chunk:find("^(.-)\r\n\r\n")
                        local chunkHeaders = {}
                        headerdata:gsub('([^%c%s:]+):%s+([^\n]+)', function(label, value)
                          label = label:lower()
                          chunkHeaders[label] = value
                        end)
                        local attrs = {}
                        if chunkHeaders["content-disposition"] then
                            chunkHeaders["content-disposition"]:gsub(';%s*([^%s=]+)="(.-)"', function(attr, val)
                                attrs[attr] = val
                            end)
                        else
                          log.e("Error processing multipart/form-data: Missing content-disposition header")
                          return self._errorHandlers[400.6](method, path, headers)
                        end
                        local value
                        local data = chunk:sub(ePos + 1):match("^(.*)\r\n$")
                        if attrs["filename"] then
                            local tmpFile, tmpFileName = cgiluaCompat.tmpfile(_parent)
                            if not tmpFile then
                                log.ef("Unable to create temporary file:%s", tmpFileName)
                                return self._errorHandlers[500](method, path, headers)
                            end
                            tmpFile:write(data)
                            tmpFile:flush()
                            tmpFile:seek("set", 0)
                            value = {
                                file          = tmpFile,
                                filename      = attrs["filename"],
                                filesize      = #data,
                                localFilename = tmpFileName,
                            }
                            for hdr, hdrval in pairs(chunkHeaders) do
                                if hdr ~= "content-disposition" then
                                    value[hdr] = hdrval
                                end
                            end
                        else
                            value = data
                        end
                        cgiluaCompat.urlcode.insertfield(_parent, M.POST, attrs["name"], value)
                    until true end
                elseif contentType == "application/json" then
                    for k, v in pairs(require"hs.json".decode(body)) do
                        cgiluaCompat.urlcode.insertfield(_parent, M.POST, k, v)
                    end
                elseif contentType == "application/xml" or contentType == "text/xml" or contentType ==  "text/plain" then
                    table.insert(M.POST, body)
                else
                    log.wf("Unsupported media type %s", contentType)
                    return self._errorHandlers[415](method, path, headers)
                end

            end

            local env = { cgilua = M, print = M.print, write = M.put, hsminweb = _parent }
            setmetatable(_parent, {
                __index = function(_, k)
                -- this is done to minimize the chances of a lua template file accidentally breaking things...
                    if k == "__luaCached_translations" then return mt_table.__luaCaches[self] end
                    if k == "__luaInternal_cgiluaENV" then return env end
                end,
                __gc = function(_)
                    for i, v in ipairs(_._tmpfiles) do
                        _._tmpfiles[i] = nil
                        if io.type(v.file) == "file" then -- as opposed to "closed file"
                            v.file:close()
                        end
                        local __, err = os.remove(v.name)
                        if not __ then log.e(err) end
                    end
                end,
            })

            setmetatable(env, {
            -- this allows "global" vars to be created for sharing between included files without polluting the real global space, while falling through to the real global space for built in functions, hs stuff, etc.
                __index    = _G,
                __newindex = function(_, k, v) rawset(_, k, v) end,
            })

            if not (self._allowRenderTranslations and CGIVariables["PATH_INFO"] == "/_translation") then
                local f, err = xpcall(cgiluaCompat.lp.compile, debug.traceback, _parent, workingBody, '@' .. targetFile, env)
                if not f then
                    log.ef("HTML-Templated-Lua translation error: %s", err)
                    if self._logBadTranslations then
                        log.vf("\n%s", textWithLineNumbers(_parent.__luaCached_translations[workingBody]))
                    end
                    return self._errorHandlers[500](method, path, headers)
                else
                    f = err -- the actual function returned when we use the xpcall
                end

                local oldWD = fs.currentDir()
                fs.chdir(M.script_pdir)
                local ok, errorMessage = xpcall(f, debug.traceback)
                fs.chdir(oldWD)

                if not ok then
                    log.ef("HTML-Templated-Lua execution error: %s", errorMessage)
                    if self._logPageErrorTranslations then
                        log.vf("\n%s", textWithLineNumbers(_parent.__luaCached_translations[workingBody]))
                    end
                    return self._errorHandlers[500](method, path, headers)
                end

                responseBody    = _parent.response.body
                responseCode    = _parent.response.code
                responseHeaders = _parent.response.headers
            else
                responseBody    = textWithLineNumbers(_parent.__luaCached_translations[workingBody] or cgiluaCompat.lp.translate(_parent, workingBody))
                responseCode    = 200
                responseHeaders["Content-Type"] = "text/plain"
            end
        end

    elseif ({ ["HEAD"] = 1, ["GET"] = 1, ["POST"] = 1 })[method] then

    -- otherwise, we can't truly POST, so treat POST as GET; it will ignore the content body which a static page can't get to anyways; POST should be handled by a function or dynamic support above -- this is a fallback for an improper form action, etc.

        if method == "POST" then method = "GET" end
        if method == "GET" or method == "HEAD" then
            if attributes.mode == "file" then
                local finput = io.open(targetFile, "rb")
                if finput then
                    if method == "GET" then -- don't actually do work for HEAD
                        responseBody = finput:read("a")
                    end
                    finput:close()
                    local contentType = fs.fileUTI(targetFile)
                    if contentType then contentType = fs.fileUTIalternate(contentType, "mime") end
                    responseHeaders["Content-Type"] = contentType
                else
                    return self._errorHandlers[403.2](method, path, headers)
                end
            elseif attributes.mode == "directory" and self._allowDirectory then
                if fs.dir(targetFile) then
                    if method == "GET" then -- don't actually do work for HEAD
                        local targetPath = pathParts.path
                        if not targetPath:match("/$") then targetPath = targetPath .. "/" end
                        responseBody = [[
                            <html>
                              <head>
                                <title>Directory listing for ]] .. targetPath .. [[</title>
                              </head>
                              <body>
                                <h1>Directory listing for ]] .. targetPath .. [[</h1>
                                <hr>
                                <pre>]]
                        for k in fs.dir(targetFile) do
                            local fattr = fs.attributes(targetFile.."/"..k)
                            if k:sub(1,1) ~= "." then
                                if fattr then
                                    responseBody = responseBody .. string.format("    %-12s %s %7.2fK <a href=\"http%s://%s%s%s\">%s%s</a>\n", fattr.mode, fattr.permissions, fattr.size / 1024, (self._ssl and "s" or ""), headers.Host, targetPath, k, k, (fattr.mode == "directory" and "/" or ""))
                                else
                                    responseBody = responseBody .. "    <i>unknown" .. string.rep(" ", 6) .. string.rep("-", 9) .. string.rep(" ", 10) .. "?? " .. k .. " ??</i>\n"
                                end
                            end
                        end
                        responseBody = responseBody .. [[</pre>
                                <hr>
                                <div align="right"><i>]] .. serverSoftware .. [[ at ]] .. headers._.queryDate .. [[</i></div>
                              </body>
                            </html>]]
                    end
                    responseHeaders["Content-Type"] = "text/html"
                else
                    return self._errorHandlers[403.2](method, path, headers)
                end
            elseif attributes.mode == "directory" then
                return self._errorHandlers[403.2](method, path, headers)
            end
        end
    else
    -- even though it's an allowed method, there is no built in support for it...
        return self._errorHandlers[405](method, path, headers)
    end

    if method == "HEAD" then responseBody = "" end -- in case it was dynamic and code gave us a body
    return responseBody, responseCode, responseHeaders
end

local webServerHandlerWrapper = function(self, method, path, headers, body)
    local queryDate = os.date("[%d/%b/%Y:%T %z]", os.time())
    local responseBody, responseCode, responseHeaders
    local answers = { xpcall(webServerHandler, debug.traceback, self, method, path, headers, body) }
    local ok = table.remove(answers, 1)
    if not ok then
        log.ef("Server Handler Error: %s", table.unpack(answers))
        responseBody, responseCode, responseHeaders = self._errorHandlers[500](method, path, headers)
    else
        responseBody, responseCode, responseHeaders = table.unpack(answers)
    end
    if self._queryLogging then
        -- more or less match Apache common format ( "%h %l %u %t \"%r\" %>s %b" ), in case anyone wants to parse it out... should we allow customizations?
        self._accessLog = self._accessLog .. string.format("%s - - %s \"%s %s HTTP/1.1\" %d %s\n", headers["X-Remote-Addr"], queryDate, method:upper(), path:gsub("%?.*$", ""), responseCode, ((#responseBody == 0) and "-" or tostring(#responseBody)))
    end
    return responseBody, responseCode, responseHeaders
end

--- hs.httpserver.hsminweb:port([port]) -> hsminwebTable | current-value
--- Method
--- Get or set the name the port the web server listens on
---
--- Parameters:
---  * port - an optional integer specifying the TCP port the server listens for requests on when it is running.  Defaults to `nil`, which causes the server to randomly choose a port when it is started.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * due to security restrictions enforced by OS X, the port must be a number greater than 1023
objectMethods.port = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        if self._server then
            self._server:setPort(args[1])
            self._port = self._server:getPort()
        else
            self._port = args[1]
        end
        return self
    else
        return self._server and self._server:getPort() or self._port
    end
end

--- hs.httpserver.hsminweb:name([name]) -> hsminwebTable | current-value
--- Method
--- Get or set the name the web server uses in Bonjour advertisement when the web server is running.
---
--- Parameters:
---  * name - an optional string specifying the name the server advertises itself as when Bonjour is enabled and the web server is running.  Defaults to `nil`, which causes the server to be advertised with the computer's name as defined in the Sharing preferences panel for the computer.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.name  = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "string", "argument must be string")
    if args.n > 0 then
        if self._server then
            self._server:setName(args[1])
            self._name = self._server:getName()
        else
            self._name = args[1]
        end
        return self
    else
        return self._server and self._server:getName() or self._name
    end
end

--- hs.httpserver.hsminweb:password([password]) -> hsminwebTable | boolean
--- Method
--- Set a password for the hsminweb web server, or return a boolean indicating whether or not a password is currently set for the web server.
---
--- Parameters:
---  * password - An optional string that contains the server password, or an explicit `nil` to remove an existing password.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or a boolean indicathing whether or not a password has been set if no parameter is specified.
---
--- Notes:
---  * the password, if set, is server wide and causes the server to use the Basic authentication scheme with an empty string for the username.
---  * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the same limitations regarding server passwords. See the documentation for `hs.httpserver.setPassword` (`help.hs.httpserver.setPassword` in the Hammerspoon console).
objectMethods.password = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "string", "argument must be string")
    if args.n > 0 then
        if self._server then
            self._server:setPassword(args[1])
            mt_table.__passwords[self] = args[1]
        else
            mt_table.__passwords[self] = args[1]
        end
        return self
    else
        return  mt_table.__passwords[self] and true or false
    end
end


--- hs.httpserver.hsminweb:maxBodySize([size]) -> hsminwebTable | current-value
--- Method
--- Get or set the maximum body size for an HTTP request
---
--- Parameters:
---  * size - An optional integer value specifying the maximum body size allowed for an incoming HTTP request in bytes.  Defaults to 10485760 (10 MB).
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * Because the Hammerspoon http server processes incoming requests completely in memory, this method puts a limit on the maximum size for a POST or PUT request.
---  * If the request body excedes this size, `hs.httpserver` will respond with a status code of 405 for the method before this module ever receives the request.
objectMethods.maxBodySize = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        if self._server then
            self._server:maxBodySize(args[1])
            self._maxBodySize = self._server:maxBodySize()
        else
            self._maxBodySize = args[1]
        end
        return self
    else
        return self._server and self._server:maxBodySize() or self._maxBodySize
    end
end

--- hs.httpserver.hsminweb:documentRoot([path]) -> hsminwebTable | current-value
--- Method
--- Get or set the document root for the web server.
---
--- Parameters:
---  * path - an optional string, default `os.getenv("HOME") .. "/Sites"`, specifying where documents for the web server should be served from.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.documentRoot = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "string", "argument must be string")
    if args.n > 0 then
        local dr = args[1]
        if dr ~= "/" and dr:match(".+/$") then
            dr = dr:match("^(.+)/$")
        end
        self._documentRoot = dr
        return self
    else
        return self._documentRoot
    end
end

--- hs.httpserver.hsminweb:ssl([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not the web server utilizes SSL for HTTP request and response communications.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not the server utilizes SSL for HTTP request and response traffic.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this flag can only be changed when the server is not running (i.e. the [hs.httpserver.hsminweb:start](#start) method has not yet been called, or the [hs.httpserver.hsminweb:stop](#stop) method is called first.)
---  * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the same considerations regarding SSL. See the documentation for `hs.httpserver.new` (`help.hs.httpserver.new` in the Hammerspoon console).
objectMethods.ssl = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        if not self._server then
            self._ssl = args[1]
            return self
        else
            error("ssl cannot be set for a running server", 2)
        end
    else
        return self._ssl
    end
end

--- hs.httpserver.hsminweb:bonjour([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not the web server should advertise itself via Bonjour when it is running.
---
--- Parameters:
---  * flag - an optional boolean, defaults to true, indicating whether or not the server should advertise itself via Bonjour when it is running.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this flag can only be changed when the server is not running (i.e. the [hs.httpserver.hsminweb:start](#start) method has not yet been called, or the [hs.httpserver.hsminweb:stop](#stop) method is called first.)
objectMethods.bonjour = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        if not self._bonjour then
            self._bonjour = args[1]
            return self
        else
            error("bonjour cannot be set for a running server", 2)
        end
    else
        return self._bonjour
    end
end

--- hs.httpserver.hsminweb:allowDirectory([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not a directory index is returned when the requested URL specifies a directory and no file matching an entry in the directory indexes table is found.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not a directory index can be returned when a default file cannot be located.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * if this value is false, then an attempt to retrieve a URL specifying a directory that does not contain a default file as identified by one of the entries in the [hs.httpserver.hsminweb:directoryIndex](#directoryIndex) list will result in a "403.2" error.
objectMethods.allowDirectory = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        self._allowDirectory = args[1]
        return self
    else
        return self._allowDirectory
    end
end

--- hs.httpserver.hsminweb:dnsLookup([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not DNS lookups are performed.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not DNS lookups are performed.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * DNS lookups can be time consuming or even block Hammerspoon for a short time, so they are disabled by default.
---  * Currently DNS lookups are (optionally) performed for CGI scripts, but may be added for other purposes in the future (logging, etc.).
objectMethods.dnsLookup = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        self._dnsLookup = args[1]
        return self
    else
        return self._dnsLookup
    end
end

--- hs.httpserver.hsminweb:queryLogging([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not requests to this web server are logged.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not query requests are logged.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * If logging is enabled, an Apache common style log entry is appended to [self._accesslog](#_accessLog) for each request made to the web server.
---  * Error messages during content generation are always logged to the Hammerspoon console via the `hs.logger` instance saved to [hs.httpserver.hsminweb.log](#log).
objectMethods.queryLogging = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        self._queryLogging = args[1]
        return self
    else
        return self._queryLogging
    end
end

--- hs.httpserver.hsminweb:directoryIndex([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the file names to look for when the requested URL specifies a directory.
---
--- Parameters:
---  * table - an optional table or `nil`, defaults to `{ "index.html", "index.htm" }`, specifying a list of file names to look for when the requested URL specifies a directory.  If a file with one of the names is found in the directory, this file is served instead of the directory.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * Files listed in this table are checked in order, so the first matched is served.  If no file match occurs, then the server will return a generated list of the files in the directory, or a "403.2" error, depending upon the value controlled by [hs.httpserver.hsminweb:allowDirectory](#allowDirectory).
objectMethods.directoryIndex = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "table", "argument must be a table of index file names")
    if args.n > 0 then
        self._directoryIndex = args[1]
        return self
    else
        return self._directoryIndex
    end
end

--- hs.httpserver.hsminweb:cgiEnabled([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not CGI file execution is enabled.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not CGI script execution is enabled for the web server.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.cgiEnabled = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "boolean", "argument must be boolean")
    if args.n > 0 then
        self._cgiEnabled = args[1]
        return self
    else
        return self._cgiEnabled
    end
end

--- hs.httpserver.hsminweb:cgiExtensions([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the file extensions which identify files which should be executed as CGI scripts to provide the results to an HTTP request.
---
--- Parameters:
---  * table - an optional table or `nil`, defaults to `{ "cgi", "pl" }`, specifying a list of file extensions which indicate that a file should be executed as CGI scripts to provide the content for an HTTP request.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this list is ignored if [hs.httpserver.hsminweb:cgiEnabled](#cgiEnabled) is not also set to true.
objectMethods.cgiExtensions = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "table", "argument must be table of file extensions")
    if args.n > 0 then
        self._cgiExtensions = args[1]
        return self
    else
        return self._cgiExtensions
    end
end

--- hs.httpserver.hsminweb:luaTemplateExtension([string]) -> hsminwebTable | current-value
--- Method
--- Get or set the extension of files which contain Lua code which should be executed within Hammerspoon to provide the results to an HTTP request.
---
--- Parameters:
---  * string - an optional string or `nil`, defaults to `nil`, specifying the file extension which indicates that a file should be executed as Lua code within the Hammerspoon environment to provide the content for an HTTP request.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * This extension is checked after the extensions given to [hs.httpserver.hsminweb:cgiExtensions](#cgiExtensions); this means that if the same extension set by this method is also in the CGI extensions list, then the file will be interpreted as a CGI script and ignore this setting.
objectMethods.luaTemplateExtension = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "string", "argument must be a file extension")
    if args.n > 0 then
        self._luaTemplateExtension = args[1]
        return self
    else
        return self._luaTemplateExtension
    end
end

--- hs.httpserver.hsminweb:scriptTimeout([integer]) -> hsminwebTable | current-value
--- Method
--- Get or set the timeout for a CGI script
---
--- Parameters:
---  * integer - an optional integer, defaults to 30, specifying the length of time in seconds a CGI script should be allowed to run before being forcibly terminated if it has not yet completed its task.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * With the current functionality available in `hs.httpserver`, any script which is expected to return content for an HTTP request must run in a blocking manner -- this means that no other Hammerspoon activity can be occurring while the script is executing.  This parameter lets you set the maximum amount of time such a script can hold things up before being terminated.
---  * An alternative implementation of at least some of the methods available in `hs.httpserver` is being considered which may make it possible to use `hs.task` for these scripts, which would alleviate this blocking behavior.  However, even if this is addressed, a timeout for scripts is still desirable so that a client making a request doesn't sit around waiting forever if a script is malformed.
objectMethods.scriptTimeout = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        self._scriptTimeout = args[1]
        return self
    else
        return self._scriptTimeout
    end
end

--- hs.httpserver.hsminweb:accessList([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the access-list table for the hsminweb web server
---
--- Parameters:
---  * table - an optional table or `nil` containing the access list for the web server, default `nil`.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * The access-list feature works by comparing the request headers against a list of tests which either accept or reject the request.  If no access list is set (i.e. it is assigned a value of `nil`), then all requests are served.  If a table is passed into this method, then any request which is not explicitly accepted by one of the tests provided is rejected (i.e. there is an implicit "reject" at the end of the list).
---  * The access-list table is a list of tests which are evaluated in order.  The first test which matches a given request determines whether or not the request is accepted or rejected.
---  * Each entry in the access-list table is also a table with the following format:
---    * { 'header', 'value', isPattern, isAccepted }
---      * header     - a string value matching the name of a header.  While the header name must match exactly, the comparison is case-insensitive (i.e. "X-Remote-addr" and "x-remote-addr" will both match the actual header name used, which is "X-Remote-Addr").
---      * value      - a string value specifying the value to compare the header key's value to.
---      * isPattern  - a boolean indicating whether or not the header key's value should be compared to `value` as a pattern match (true) -- see Lua documentation 6.4.1, `help.lua._man._6_4_1` in the console, or as an exact match (false)
---      * isAccepted - a boolean indicating whether or not a match should be accepted (true) or rejected (false)
---    * A special entry of the form { '\*', '\*', '\*', true } accepts all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to reject, but to accept any requests which do not match a previous test.
---    * A special entry of the form { '\*', '\*', '\*', false } rejects all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to accept, but to reject any requests which do not match a previous test.  This is the implicit "default" final test if a table is assigned with the access-list method and does not actually need to be specified, but is included for completeness.
---    * Note that any entry after an entry in which the first two parameters are equal to '\*' will never actually be used.
---
---  * The tests are performed in order; if you wich to allow one IP address in a range, but reject all others, you should list the accepted IP addresses first. For example:
---     ~~~
---     {
---        { 'X-Remote-Addr', '192.168.1.100',  false, true },  -- accept requests from 192.168.1.100
---        { 'X-Remote-Addr', '^192%.168%.1%.', true,  false }, -- reject all others from the 192.168.1 subnet
---        { '*',             '*',              '*',   true }   -- accept all other requests
---     }
---     ~~~
---
---  * Most of the headers available are provided by the requesting web browser, so the exact headers available will vary.  You can find some information about common HTTP request headers at: https://en.wikipedia.org/wiki/List_of_HTTP_header_fields.
---
---  * The following headers are inserted automatically by `hs.httpserver` and are probably the most useful for use in an access list:
---    * X-Remote-Addr - the remote IPv4 or IPv6 address of the machine making the request,
---    * X-Remote-Port - the TCP port of the remote machine where the request originated.
---    * X-Server-Addr - the server IPv4 or IPv6 address that the web server received the request from.  For machines with multiple interfaces, this will allow you to determine which interface the request was received on.
---    * X-Server-Port - the TCP port of the web server that received the request.
objectMethods.accessList = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1]) == "table", "argument must be table of access requirements")
    if args.n > 0 then
        self._accessList = args[1]
        return self
    else
        return self._accessList
    end
end

--- hs.httpserver.hsminweb:interface([interface]) -> hsminwebTable | current-value
--- Method
--- Get or set the network interface that the hsminweb web server will listen on
---
--- Parameters:
---  * interface - an optional string, or nil, specifying the network interface the web server will listen on.  An explicit nil specifies that the web server should listen on all active interfaces for the machine.  Defaults to nil.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * See `hs.httpserver.setInterface` for a description of valid values that can be specified as the `interface` argument to this method.
---  * the interface can only be specified before the hsminweb web server has been started.  If you wish to change the listening interface for a running web server, you must stop it with [hs.httpserver.hsminweb:stop](#stop) before invoking this method and then restart it with [hs.httpserver.hsminweb:start](#start).
objectMethods.interface = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._interface
    else
        if not self._server then
            if args[1] == nil or type(args[1]) == "string" then
                self._interface = args[1]
            else
                error("interface must be nil or a string", 2)
            end
        else
            error("cannot set the interface on a running hsminweb web server", 2)
        end
        return self
    end
end

--- hs.httpserver.hsminweb:start() -> hsminwebTable
--- Method
--- Start serving pages for the hsminweb web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the hsminWebTable object
objectMethods.start = function(self)
    if not self._server then
        self._ssl     = self._ssl or false
        self._bonjour = (type(self._bonjour) == "nil") and true or self._bonjour
        self._server  = require"hs.httpserver".new(self._ssl, self._bonjour):setCallback(function(...)
            return webServerHandlerWrapper(self, ...)
        end)

        if self._port                 then self._server:setPort(self._port) end
        if self._name                 then self._server:setName(self._name) end
        if self._maxBodySize          then self._server:maxBodySize(self._maxBodySize) end
        if self._interface            then self._server:setInterface(self._interface) end
        if mt_table.__passwords[self] then self._server:setPassword(mt_table.__passwords[self]) end

        self._server:start()

        return self
    else
        error("server already started", 2)
    end
end

--- hs.httpserver.hsminweb:stop() -> hsminwebTable
--- Method
--- Stop serving pages for the hsminweb web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the hsminWebTable object
---
--- Notes:
---  * this method is called automatically during garbage collection.
objectMethods.stop = function(self)
    if self._server then
        self._server:stop()
        self._server = nil
        return self
    else
        error("server not currently running", 2)
    end
end

objectMethods.__gc = function(self)
    if self._server then self:stop() end
end

--- hs.httpserver.hsminweb.new([documentRoot]) -> hsminwebTable
--- Constructor
--- Create a new hsminweb table object representing a Hammerspoon Web Server.
---
--- Parameters:
---  * documentRoot - an optional string specifying the document root for the new web server.  Defaults to the Hammerspoon users `Sites` sub-directory (i.e. `os.getenv("HOME").."/Sites"`).
---
--- Returns:
---  * a table representing the hsminweb object.
---
--- Notes:
---  * a web server's document root is the directory which contains the documents or files to be served by the web server.
---  * while an hs.minweb object is actually represented by a Lua table, it has been assigned a meta-table which allows methods to be called directly on it like a user-data object.  For most purposes, you should think of this table as the module's userdata.
module.new = function(documentRoot)
    documentRoot = documentRoot or os.getenv("HOME").."/Sites"
    if documentRoot ~= "/" and documentRoot:match(".+/$") then
        documentRoot = documentRoot:match("^(.+)/$")
    end

    local instance = {
        _documentRoot     = documentRoot,
        _directoryIndex   = shallowCopy(directoryIndex),
        _cgiExtensions    = shallowCopy(cgiExtensions),
        _serverAdmin      = serverAdmin,

        _errorHandlers    = setmetatable({}, errorHandlers),
        _supportedMethods = setmetatable({}, { __index = supportedMethods }),

        _accessLog        = "",
    }

    -- make it easy to see which methods are supported
    for k, v in pairs(supportedMethods) do if v then instance._supportedMethods[k] = v end end

    -- save tostring(instance) since we override it, but I like the address so it looks more "formal" in the console...
    mt_table.__tostrings[instance] = tostring(instance)
    mt_table.__luaCaches[instance] = {}

    return setmetatable(instance, mt_table)
end

--- hs.httpserver.hsminweb._serverAdmin
--- Variable
--- Accessed as `self._serverAdmin`.  A string containing the administrator for the web server.  Defaults to the currently logged in user's short form username and the computer's localized name as returned by `hs.host.localizedName()` (e.g. "user@computer").
---
--- This value is often used in error messages or on error pages indicating a point of contact for administrative help.  It can be accessed from within an error helper functions as `headers._.serverAdmin`.

--- hs.httpserver.hsminweb._accessLog
--- Variable
--- Accessed as `self._accessLog`.  If query logging is enabled for the web server, an Apache style common log entry will be appended to this string for each request.  See [hs.httpserver.hsminweb:queryLogging](#queryLogging).

--- hs.httpserver.hsminweb._errorHandlers
--- Variable
--- Accessed as `self._errorHandlers[errorCode]`.  A table whose keyed entries specify the function to generate the error response page for an HTTP error.
---
--- HTTP uses a three digit numeric code for error conditions.  Some servers have introduced subcodes, which are appended as a decimal added to the error condition.
---
--- You can assign your own handler to customize the response for a specific error code by specifying a function for the desired error condition as the value keyed to the error code as a string key in this table.  The function should expect three arguments:
---  * method  - the method for the HTTP request
---  * path    - the full path, including any GET query items
---  * headers - a table containing key-value pairs for the HTTP request headers
---
--- If you override the default handler, "default", the function should expect four arguments instead:  the error code as a string, followed by the same three arguments defined above.
---
--- In either case, the function should return three values:
---  * body    - the content to be returned, usually HTML for a basic error description page
---  * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
---  * headers - a table containing any headers which should be included in the HTTP response.

--- hs.httpserver.hsminweb._supportMethods
--- Variable
--- Accessed as `self._supportMethods[method]`.  A table whose keyed entries specify whether or not a specified HTTP method is supported by this server.
---
--- The default methods supported internally are:
---  * HEAD - an HTTP method which verifies whether or not a resource is available and it's last modified date
---  * GET  - an HTTP method requesting content; the default method used by web browsers for bookmarks or URLs typed in by the user
---  * POST - an HTTP method requesting content that includes content in the request body, most often used by forms to include user input or file data which may affect the content being returned.
---
--- If you assign `true` to another method key, then it will be supported if the target URL refers to a CGI script or Lua Template file, and their support has been enabled for the server.
---
--- If you assign `false` to a method key, then *any* request utilizing that method will return a status of 405 (Method Not Supported).  E.g. `self._supportMethods["POST"] = false` will prevent the POST method from being supported.
---
--- Common HTTP request methods can be found at https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods and https://en.wikipedia.org/wiki/WebDAV.  Currently, only HEAD, GET, and POST have built in support for static pages; even if you set other methods to `true`, they will return a status code of 405 (Method Not Supported) if the request does not invoke a CGI file or Lua Template file for dynamic content.
---
--- A companion module supporting the methods required for WebDAV is being considered.


--- hs.httpserver.hsminweb.dateFormatString
--- Constant
--- A format string, usable with `os.date`, which will display a date in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
module.dateFormatString = HTTPdateFormatString

--- hs.httpserver.hsminweb.formattedDate([date]) -> string
--- Function
--- Returns the current or specified time in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
---
--- Parameters:
---  * date - an optional integer specifying the date as the number of seconds since 00:00:00 UTC on 1 January 1970.  Defaults to the current time as returned by `os.time()`
---
--- Returns:
---  * the time indicated as a string in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
module.formattedDate    = HTTPformattedDate

--- hs.httpserver.hsminweb.urlParts(url) -> table
--- Function
--- Parse the specified URL into it's constituant parts.
---
--- Parameters:
---  * url - the url to parse
---
--- Returns:
---  * a table containing the constituant parts of the provided url.  The table will contain one or more of the following key-value pairs:
---    * fragment           - the anchor name a URL refers to within an HTML document.  Appears after '#' at the end of a URL.  Note that not all web clients include this in an HTTP request since its normal purpose is to indicate where to scroll to within a page after the content has been retrieved.
---    * host               - the host name portion of the URL, if any
---    * lastPathComponent  - the last component of the path portion of the URL
---    * password           - the password specified in the URL.  Note that this is not the password that would be entered when using Basic or Digest authentication; rather it is a password included in the URL itself -- for security reasons, use of this field has been deprecated in most situations and modern browsers will often prompt for confirmation before allowing URL's which contain a password to be transmitted.
---    * path               - the full path specified in the URL
---    * pathComponents     - an array containing the path components as individual strings.  Components which specify a sub-directory of the path will end with a "/" character.
---    * pathExtension      - if the final component of the path refers to a file, the file's extension, if any.
---    * port               - the port specified in the URL, if any
---    * query              - the portion of the URL after a '?' character, if any; used to contain query information often from a form submitting it's input with the GET method.
---    * resourceSpecifier  - the portion of the URL after the scheme
---    * scheme             - the URL scheme; for web traffic, this will be "http" or "https"
---    * standardizedURL    - the URL with any path components of ".." or "." normalized.  The use of ".." that would cause the URL to refer to something preceding its root is simply removed.
---    * URL                - the URL as it was provided to this function (no changes)
---    * user               - the user name specified in the URL.  Note that this is not the user name that would be entered when using Basic or Digest authentication; rather it is a user name included in the URL itself -- for security reasons, use of this field has been deprecated in most situations and modern browsers will often prompt for confirmation before allowing URL's which contain a user name to be transmitted.
---
--- Notes:
---  * This function differs from the similar function `hs.http.urlParts` in a few ways:
---    * To simplify the logic used by this module to determine if a request for a directory is properly terminated with a "/", the path components returned by this function do not remove this character from the component, if present.
---    * Some extraneous or duplicate keys have been removed.
---    * This function is patterned after RFC 3986 while `hs.http.urlParts` uses OS X API functions which are patterned after RFC 1808. RFC 3986 obsoletes 1808.  The primary distinction that affects this module is in regards to `parameters` for path components in the URI -- RFC 3986 disallows them in schema based URI's (like the URL's that are used for web based traffic).
module.urlParts = RFC3986getURLParts

--- hs.httpserver.hsminweb.log
--- Variable
--- The `hs.logger` instance for the `hs.httpserver.hsminweb` module. See the documentation for `hs.logger` for more information.
module.log = log

--- hs.httpserver.hsminweb.statusCodes
--- Constant
--- HTTP Response Status Codes
---
--- This table contains a list of common HTTP status codes identified from various sources (see Notes below). Because some web servers append a subcode after the official HTTP status codes, the keys in this table are the string representation of the numeric code so a distinction can be made between numerically "identical" keys (for example, "404.1" and "404.10").  You can reference this table with a numeric key, however, and it will be converted to its string representation internally.
---
--- Notes:
---  * The keys and labels in this table have been combined from a variety of sources including, but not limited to:
---    * "Official" list at https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
---    * KeplerProject's wsapi at https://github.com/keplerproject/wsapi
---    * IIS additions from https://support.microsoft.com/en-us/kb/943891
---  * This table has metatable additions which allow you to review its contents from the Hammerspoon console by typing `hs.httpserver.hsminweb.statusCodes`
module.statusCodes = setmetatable(statusCodes, {
    __tostring = function(_)
        local outputList = {}
        for k, v in pairs(_) do table.insert(outputList, string.format("%-7s %s", k, v)) end
        table.sort(outputList, function(a, b) return a:sub(1,7) < b:sub(1,7) end)
        return table.concat(outputList, "\n")
    end,
    __index = function(_, k)
        return rawget(_, tostring(k)) or nil
    end,
})

return module
