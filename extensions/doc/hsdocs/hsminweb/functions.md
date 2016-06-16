Customizing `hs.httpserver.hsminweb` Error Pages
------------------------------------------------

Custom functions can be defined to provide custom error pages for each web server instance provided by `hs.httpserver.hsminweb`.  For the code examples provided here, it is assumed that you have an `hs.httpserver.hsminweb` instance available in `server`.  A barebones server instance can be created with:

~~~lua
server = require("hs.httpserver.hsminweb").new():start()
~~~

You can identify the server's port by typing `server:port()` into the Hammerspoon console or create a server instance on a specific port by using methods described in the documentation for `hs.httpserver.hsminweb`.

- - -

### Custom Error Functions for a Specific Response Code

By default, the HTTP error pages are pretty bland:

<table align="center" style="width: 75%;"><tr><td>
<H1>HTTP/1.1 404 Not Found</H1>
<br/>
<br/>
<hr/>
<div align="right"><i>hsminweb/0.0.5 (OSX) at Tue, 26 Apr 2016 20:50:13 GMT</i></div>
</td></tr></table>

You can provide a custom function to make a more descriptive error page for a specific error code, or for all errors which do not have a custom function by adding them to the `server._errorHandlers` table.

404 is the error code for a missing resource, usually because the URL refers to a file that does not exist.  You can see a list of the common error codes and their basic description by typing `hs.httpserver.hsminweb.statusCodes` into the Hammerspoon console.  Any number over 400 indicates an error condition.  404 is probably the most commonly encountered, and to provide a more descriptive error, you could do something like this:

~~~lua
server._errorHandlers["404"] = function(method, path, headers)
    local responseBody, responseCode, responseHeaders = "", 404, {}

    ... code to fill responseBody and responseHeaders ...

    return responseBody, responseCode, responseHeaders
end
~~~

Note first that the key to the `server._errorHandlers` table is provided a string.  This is done because some web servers have expanded the status codes with a decimal portion to provide a more specific error condition.  Unfortunately, Lua does not distinguish between the table key of `404` and `404.0`, even though some servers do.  For that reason, to allow you the most flexibility in what error codes you want to be able to use when specifying an error, this key is handled as a string.

Note also that the return code is an integer -- this is because the HTTP specification requires that the error code be an integer.  While the server may describe an error condition with an error number with a decimal portion, the protocol specifies that any decimal portion is dropped before returning the code number in the response.  This applies only to the headers sent between the server and the client -- the message body can still contain whatever text you prefer, including the status code with a decimal.  It also means that an error of `404.1`, which IIS uses to specify that the site specified was not found, at its most basic, is still a `404` error -- an error indicating that the resource was not found, for whatever reason.

You can also change the status code if you choose -- the `responseCode` returned is what the server will send to the client.  For example, some minimal web servers found in embedded systems will return a `500` error code for *all* errors -- typically `500` specifies an *Internal Server Error*, but to save space, embedded servers treat anything they can't handle equally; depending upon your web client, a specific error number may not be useful and if you need to mimic a simpler behavior, this fact allows you to conform to such a system's expectations (though it's probably beter in such a case to replace the default function, which is described in a later section).

The `method`, `path`, and `headers` fields match the originating request sent by the web client.  To aid in developing your own custom functions, the `headers` table is also assigned a `_` key, which will contain some internally generated information about the request and the server, and is described in more detail at the end of this document.  A more complete example of a replacement error for `404` might look something like this:

~~~lua
server._errorHandlers["404"] = function(method, path, headers)
    local responseCode = 404
    local responseBody = [[
<html>
  <head>
    <title>Not Found</title>
  </head>
  <body>
    <H1>HTTP/1.1 404 Not Found</H1>
    The requested resource, ]] .. headers._.pathParts.URL .. [[, was not found or is not available.
    <br/>
    <br/>
    <hr/>
    <div align="right">
      <i>]] .. headers._.serverSoftware .. [[ at ]] .. headers._.queryDate .. [[</i>
    </div>
  </body>
</html>
]]
    local responseHeaders = headers._.minimalHTMLResponseHeaders
    return responseBody, responseCode, responseHeaders
end
~~~

Now, a `404` error returns this (admittedly its not a huge change, but serves as an example):

<table align="center" style="width: 75%;"><tr><td>
<H1>HTTP/1.1 404 Not Found</H1>
The requested resource, http://localhost:12345/s.lp/functions.md, was not found or is not available.
<br/>
<br/>
<hr/>
<div align="right">
  <i>hsminweb/0.0.5 (OSX) at Tue, 26 Apr 2016 22:08:40 GMT</i>
</div>
</td></tr></table>

The use of the predefined `headers._.minimalHTMLResponseHeaders` provides a minimal set of response headers necessary for an HTML response.

### Custom Default Error Function (Catch-All)

The default error function is used to generate the output for any error which does not already have a handler.  By default, this is the only error function actually defined in an `hs.httpserver.hsminweb` instance, and it uses the status code list in `hs.httpserver.hsminweb.statusCodes` to determine the text of the title and in the first line of the default output.  Defining your own default error handler is very similar to defining a specific error handler, but takes an additional argument specifying the requested error status code.  You can define a custom handler like this:

~~~lua
server._errorHandlers["default"] = function(code, method, path, headers)
    local responseBody, responseCode, responseHeaders = "", code, {}

    ... code to fill responseBody and responseHeaders ...

    return responseBody, responseCode, responseHeaders
end
~~~

Because this may be called with the code specified as a string or a number, a couple of extra steps are recommended, and here is a full example:

~~~lua
server._errorHandlers["default"] = function(code, method, path, headers)
    if type(code) == "number" then code = tostring(code) end

    -- remember that the actual response code returned must be an integer
    local responseCode = math.floor(tonumber(code))
    local defaultTitle = hs.httpserver.hsminweb.statusCodes[code]
    if not defaultTitle then
        responseCode = 500
        defaultTitle = "Unrecognized Status Code"
    end

    local responseBody = [[
<html>
  <head>
    <title>]] .. defaultTitle .. [[</title>
  </head>
  <body>
    <H1>HTTP/1.1 ]] .. tostring(responseCode) .. [[ ]] .. defaultTitle .. [[</H1>
    Requesting the resource, ]] .. headers._.pathParts.URL .. [[, resulted in an error.
    <br/>]]

    if responseCode ~= math.floor(tonumber(code)) then
        responseBody = responseBody .. [[
    In addition, the specified status code, ]] .. code .. [[, is unrecognized.<br/>
]]
    end

    responseBody = responseBody .. [[
    <br/>
    <hr/>
    <div align="right">
      <i>]] .. headers._.serverSoftware .. [[ at ]] .. headers._.queryDate .. [[</i>
    </div>
  </body>
</html>
]]

    return responseBody, responseCode, headers._.minimalHTMLResponseHeaders
end
~~~

- - -

### Server Information in `headers._`

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

