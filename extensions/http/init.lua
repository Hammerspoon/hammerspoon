-- Simple loader for the Objective C code
local http = require("hs.http.internal")

--- === hs.http ===
---
--- Perform HTTP requests

--- hs.http.get(url, headers) -> int, string, table
--- Function
--- Sends an HTTP GET request to a URL
---
--- Parameters
---  * url - A string containing the URL to retrieve
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---
--- Returns:
---  * A number containing the HTTP response status
---  * A string containing the response body
---  * A table containing the response headers
---
--- Notes:
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
http.get = function(url, headers)
    return http.doRequest(url, "GET", nil, headers)
end

--- hs.http.post(url, data, headers) -> int, string, table
--- Function
--- Sends an HTTP POST request to a URL
---
--- Parameters
---  * url - A string containing the URL to submit to
---  * data - A string containing the request body, or nil to send no body
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---
--- Returns:
---  * A number containing the HTTP response status
---  * A string containing the response body
---  * A table containing the response headers
---
--- Notes:
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
http.post = function(url, data, headers)
    return http.doRequest(url, "POST", data,headers)
end

--- hs.http.asyncGet(url, headers, callback)
--- Function
--- Sends an HTTP GET request asynchronously
---
--- Parameters:
---  * url - A string containing the URL to retrieve
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---  * callback - A function to be called when the request succeeds or fails. The function will be passed three parameters:
---   * A number containing the HTTP response status
---   * A string containing the response body
---   * A table containing the response headers
---
--- Notes:
---  * If the request fails, the callback function's first parameter will be negative and the second parameter will contain an error message. The third parameter will be nil
http.asyncGet = function(url, headers, callback)
    http.doAsyncRequest(url, "GET", nil, headers, callback)
end

--- hs.http.asyncPost(url, data, headers, callback)
--- Function
--- Sends an HTTP POST request asynchronously
---
--- Parameters:
---  * url - A string containing the URL to submit to
---  * data - A string containing the request body, or nil to send no body
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---  * callback - A function to be called when the request succeeds or fails. The function will be passed three parameters:
---   * A number containing the HTTP response status
---   * A string containing the response body
---   * A table containing the response headers
---
--- Notes:
---  * If the request fails, the callback function's first parameter will be negative and the second parameter will contain an error message. The third parameter will be nil
http.asyncPost = function(url, data, headers, callback)
    http.doAsyncRequest(url, "POST", data, headers, callback)
end

return http
