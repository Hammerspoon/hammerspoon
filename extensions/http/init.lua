-- Simple loader for the Objective C code
local http = require("hs.http.internal")

local utf8    = require("hs.utf8")
local fnutils = require("hs.fnutils")

--- === hs.http ===
---
--- Perform HTTP requests

--- hs.http.get(url, headers) -> int, string, table
--- Function
--- Sends an HTTP GET request to a URL
---
--- Parameters:
---  * url - A string containing the URL to retrieve
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---
--- Returns:
---  * A number containing the HTTP response status
---  * A string containing the response body
---  * A table containing the response headers
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
---  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.http.asyncGet](#asyncGet) to avoid this.
http.get = function(url, headers)
    return http.doRequest(url, "GET", nil, headers)
end

--- hs.http.post(url, data, headers) -> int, string, table
--- Function
--- Sends an HTTP POST request to a URL
---
--- Parameters:
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
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
---  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.http.asyncPost](#asyncPost) to avoid this.
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
--- Returns:
---  * None
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
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
--- Returns:
---  * None
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * If the request fails, the callback function's first parameter will be negative and the second parameter will contain an error message. The third parameter will be nil
http.asyncPost = function(url, data, headers, callback)
    http.doAsyncRequest(url, "POST", data, headers, callback)
end

--- hs.http.htmlEntities[]
--- Variable
--- A collection of common HTML Entities (&whatever;) and their UTF8 equivalents.  To retrieve the UTF8 sequence for a given entity, reference the table as `hs.http.htmlEntities["&key;"]` where `key` is the text of the entity's name or a numeric reference like `#number`.
---
--- Notes:
---  * This list is likely not complete.  It is based on the list of common entities described at http://www.freeformatter.com/html-entities.html.
---  * Additional entities can be temporarily added via the `hs.http.registerEntity(...)` function.  If you feel you have a more official list of entities which contains items which are currently not included by default, please open up an issue at https://github.com/Hammerspoon/hammerspoon and your link will be considered.
---  * To see a list of the currently defined entities, a __tostring meta-method is included so that referencing the table directly as a string will return the current definitions.
---    * For reference, this meta-method is essentially the following:
---
---      for i,v in hs.fnutils.sortByKeys(hs.http.htmlEntities) do print(string.format("%-10s %-10s %s\n", i, "&#"..tostring(hs.utf8.codepoint(v))..";", v)) end
---
---    * Note that this list will not include the numeric conversion of entities (e.g. &#65;), as this is handled by an __index metamethod to allow for all possible numeric values.
http.htmlEntities = setmetatable({}, { __index = function(_, key)
          if type(key) == "string" then
              local num = key:match("^&#(%d+);$")
              if num and tonumber(num) then
                  return utf8.codepointToUTF8(tonumber(num))
              else
                  return nil
              end
          else
              return nil
          end
    end,
     __tostring = function(object)
            local output = ""
            for i,v in fnutils.sortByKeys(object) do
                output = output..string.format("%-10s %-10s %s\n", i, "&#"..tostring(utf8.codepoint(v))..";", v)
            end
            return output
    end
})

http.htmlEntities["&Aacute;"]    = utf8.codepointToUTF8(193)
http.htmlEntities["&aacute;"]    = utf8.codepointToUTF8(225)
http.htmlEntities["&Acirc;"]     = utf8.codepointToUTF8(194)
http.htmlEntities["&acirc;"]     = utf8.codepointToUTF8(226)
http.htmlEntities["&acute;"]     = utf8.codepointToUTF8(180)
http.htmlEntities["&AElig;"]     = utf8.codepointToUTF8(198)
http.htmlEntities["&aelig;"]     = utf8.codepointToUTF8(230)
http.htmlEntities["&Agrave;"]    = utf8.codepointToUTF8(192)
http.htmlEntities["&agrave;"]    = utf8.codepointToUTF8(224)
http.htmlEntities["&Alpha;"]     = utf8.codepointToUTF8(913)
http.htmlEntities["&alpha;"]     = utf8.codepointToUTF8(945)
http.htmlEntities["&amp;"]       = utf8.codepointToUTF8(38)
http.htmlEntities["&and;"]       = utf8.codepointToUTF8(8743)
http.htmlEntities["&ang;"]       = utf8.codepointToUTF8(8736)
http.htmlEntities["&Aring;"]     = utf8.codepointToUTF8(197)
http.htmlEntities["&aring;"]     = utf8.codepointToUTF8(229)
http.htmlEntities["&asymp;"]     = utf8.codepointToUTF8(8776)
http.htmlEntities["&Atilde;"]    = utf8.codepointToUTF8(195)
http.htmlEntities["&atilde;"]    = utf8.codepointToUTF8(227)
http.htmlEntities["&Auml;"]      = utf8.codepointToUTF8(196)
http.htmlEntities["&auml;"]      = utf8.codepointToUTF8(228)
http.htmlEntities["&bdquo;"]     = utf8.codepointToUTF8(8222)
http.htmlEntities["&Beta;"]      = utf8.codepointToUTF8(914)
http.htmlEntities["&beta;"]      = utf8.codepointToUTF8(946)
http.htmlEntities["&brvbar;"]    = utf8.codepointToUTF8(166)
http.htmlEntities["&bull;"]      = utf8.codepointToUTF8(8226)
http.htmlEntities["&cap;"]       = utf8.codepointToUTF8(8745)
http.htmlEntities["&Ccedil;"]    = utf8.codepointToUTF8(199)
http.htmlEntities["&ccedil;"]    = utf8.codepointToUTF8(231)
http.htmlEntities["&cedil;"]     = utf8.codepointToUTF8(184)
http.htmlEntities["&cent;"]      = utf8.codepointToUTF8(162)
http.htmlEntities["&Chi;"]       = utf8.codepointToUTF8(935)
http.htmlEntities["&chi;"]       = utf8.codepointToUTF8(967)
http.htmlEntities["&circ;"]      = utf8.codepointToUTF8(710)
http.htmlEntities["&clubs;"]     = utf8.codepointToUTF8(9827)
http.htmlEntities["&cong;"]      = utf8.codepointToUTF8(8773)
http.htmlEntities["&copy;"]      = utf8.codepointToUTF8(169)
http.htmlEntities["&crarr;"]     = utf8.codepointToUTF8(8629)
http.htmlEntities["&cup;"]       = utf8.codepointToUTF8(8746)
http.htmlEntities["&curren;"]    = utf8.codepointToUTF8(164)
http.htmlEntities["&dagger;"]    = utf8.codepointToUTF8(8224)
http.htmlEntities["&Dagger;"]    = utf8.codepointToUTF8(8225)
http.htmlEntities["&darr;"]      = utf8.codepointToUTF8(8595)
http.htmlEntities["&deg;"]       = utf8.codepointToUTF8(176)
http.htmlEntities["&Delta;"]     = utf8.codepointToUTF8(916)
http.htmlEntities["&delta;"]     = utf8.codepointToUTF8(948)
http.htmlEntities["&diams;"]     = utf8.codepointToUTF8(9830)
http.htmlEntities["&divide;"]    = utf8.codepointToUTF8(247)
http.htmlEntities["&Eacute;"]    = utf8.codepointToUTF8(201)
http.htmlEntities["&eacute;"]    = utf8.codepointToUTF8(233)
http.htmlEntities["&Ecirc;"]     = utf8.codepointToUTF8(202)
http.htmlEntities["&ecirc;"]     = utf8.codepointToUTF8(234)
http.htmlEntities["&Egrave;"]    = utf8.codepointToUTF8(200)
http.htmlEntities["&egrave;"]    = utf8.codepointToUTF8(232)
http.htmlEntities["&empty;"]     = utf8.codepointToUTF8(8709)
http.htmlEntities["&emsp;"]      = utf8.codepointToUTF8(8195)
http.htmlEntities["&ensp;"]      = utf8.codepointToUTF8(8194)
http.htmlEntities["&Epsilon;"]   = utf8.codepointToUTF8(917)
http.htmlEntities["&epsilon;"]   = utf8.codepointToUTF8(949)
http.htmlEntities["&equiv;"]     = utf8.codepointToUTF8(8801)
http.htmlEntities["&Eta;"]       = utf8.codepointToUTF8(919)
http.htmlEntities["&eta;"]       = utf8.codepointToUTF8(951)
http.htmlEntities["&ETH;"]       = utf8.codepointToUTF8(208)
http.htmlEntities["&eth;"]       = utf8.codepointToUTF8(240)
http.htmlEntities["&Euml;"]      = utf8.codepointToUTF8(203)
http.htmlEntities["&euml;"]      = utf8.codepointToUTF8(235)
http.htmlEntities["&euro;"]      = utf8.codepointToUTF8(8364)
http.htmlEntities["&exist;"]     = utf8.codepointToUTF8(8707)
http.htmlEntities["&fnof;"]      = utf8.codepointToUTF8(402)
http.htmlEntities["&forall;"]    = utf8.codepointToUTF8(8704)
http.htmlEntities["&frac12;"]    = utf8.codepointToUTF8(189)
http.htmlEntities["&frac14;"]    = utf8.codepointToUTF8(188)
http.htmlEntities["&frac34;"]    = utf8.codepointToUTF8(190)
http.htmlEntities["&Gamma;"]     = utf8.codepointToUTF8(915)
http.htmlEntities["&gamma;"]     = utf8.codepointToUTF8(947)
http.htmlEntities["&ge;"]        = utf8.codepointToUTF8(8805)
http.htmlEntities["&gt;"]        = utf8.codepointToUTF8(62)
http.htmlEntities["&harr;"]      = utf8.codepointToUTF8(8596)
http.htmlEntities["&hearts;"]    = utf8.codepointToUTF8(9829)
http.htmlEntities["&hellip;"]    = utf8.codepointToUTF8(8230)
http.htmlEntities["&Iacute;"]    = utf8.codepointToUTF8(205)
http.htmlEntities["&iacute;"]    = utf8.codepointToUTF8(237)
http.htmlEntities["&Icirc;"]     = utf8.codepointToUTF8(206)
http.htmlEntities["&icirc;"]     = utf8.codepointToUTF8(238)
http.htmlEntities["&iexcl;"]     = utf8.codepointToUTF8(161)
http.htmlEntities["&Igrave;"]    = utf8.codepointToUTF8(204)
http.htmlEntities["&igrave;"]    = utf8.codepointToUTF8(236)
http.htmlEntities["&infin;"]     = utf8.codepointToUTF8(8734)
http.htmlEntities["&int;"]       = utf8.codepointToUTF8(8747)
http.htmlEntities["&Iota;"]      = utf8.codepointToUTF8(921)
http.htmlEntities["&iota;"]      = utf8.codepointToUTF8(953)
http.htmlEntities["&iquest;"]    = utf8.codepointToUTF8(191)
http.htmlEntities["&isin;"]      = utf8.codepointToUTF8(8712)
http.htmlEntities["&Iuml;"]      = utf8.codepointToUTF8(207)
http.htmlEntities["&iuml;"]      = utf8.codepointToUTF8(239)
http.htmlEntities["&Kappa;"]     = utf8.codepointToUTF8(922)
http.htmlEntities["&kappa;"]     = utf8.codepointToUTF8(954)
http.htmlEntities["&Lambda;"]    = utf8.codepointToUTF8(923)
http.htmlEntities["&lambda;"]    = utf8.codepointToUTF8(955)
http.htmlEntities["&laquo;"]     = utf8.codepointToUTF8(171)
http.htmlEntities["&larr;"]      = utf8.codepointToUTF8(8592)
http.htmlEntities["&lceil;"]     = utf8.codepointToUTF8(8968)
http.htmlEntities["&ldquo;"]     = utf8.codepointToUTF8(8220)
http.htmlEntities["&le;"]        = utf8.codepointToUTF8(8804)
http.htmlEntities["&lfloor;"]    = utf8.codepointToUTF8(8970)
http.htmlEntities["&lowast;"]    = utf8.codepointToUTF8(8727)
http.htmlEntities["&loz;"]       = utf8.codepointToUTF8(9674)
http.htmlEntities["&lrm;"]       = utf8.codepointToUTF8(8206)
http.htmlEntities["&lsaquo;"]    = utf8.codepointToUTF8(8249)
http.htmlEntities["&lsquo;"]     = utf8.codepointToUTF8(8216)
http.htmlEntities["&lt;"]        = utf8.codepointToUTF8(60)
http.htmlEntities["&macr;"]      = utf8.codepointToUTF8(175)
http.htmlEntities["&mdash;"]     = utf8.codepointToUTF8(8212)
http.htmlEntities["&micro;"]     = utf8.codepointToUTF8(181)
http.htmlEntities["&middot;"]    = utf8.codepointToUTF8(183)
http.htmlEntities["&minus;"]     = utf8.codepointToUTF8(8722)
http.htmlEntities["&Mu;"]        = utf8.codepointToUTF8(924)
http.htmlEntities["&mu;"]        = utf8.codepointToUTF8(956)
http.htmlEntities["&nabla;"]     = utf8.codepointToUTF8(8711)
http.htmlEntities["&nbsp;"]      = utf8.codepointToUTF8(160)
http.htmlEntities["&ndash;"]     = utf8.codepointToUTF8(8211)
http.htmlEntities["&ne;"]        = utf8.codepointToUTF8(8800)
http.htmlEntities["&ni;"]        = utf8.codepointToUTF8(8715)
http.htmlEntities["&not;"]       = utf8.codepointToUTF8(172)
http.htmlEntities["&notin;"]     = utf8.codepointToUTF8(8713)
http.htmlEntities["&nsub;"]      = utf8.codepointToUTF8(8836)
http.htmlEntities["&Ntilde;"]    = utf8.codepointToUTF8(209)
http.htmlEntities["&ntilde;"]    = utf8.codepointToUTF8(241)
http.htmlEntities["&Nu;"]        = utf8.codepointToUTF8(925)
http.htmlEntities["&nu;"]        = utf8.codepointToUTF8(957)
http.htmlEntities["&Oacute;"]    = utf8.codepointToUTF8(211)
http.htmlEntities["&oacute;"]    = utf8.codepointToUTF8(243)
http.htmlEntities["&Ocirc;"]     = utf8.codepointToUTF8(212)
http.htmlEntities["&ocirc;"]     = utf8.codepointToUTF8(244)
http.htmlEntities["&OElig;"]     = utf8.codepointToUTF8(338)
http.htmlEntities["&oelig;"]     = utf8.codepointToUTF8(339)
http.htmlEntities["&Ograve;"]    = utf8.codepointToUTF8(210)
http.htmlEntities["&ograve;"]    = utf8.codepointToUTF8(242)
http.htmlEntities["&oline;"]     = utf8.codepointToUTF8(8254)
http.htmlEntities["&Omega;"]     = utf8.codepointToUTF8(937)
http.htmlEntities["&omega;"]     = utf8.codepointToUTF8(969)
http.htmlEntities["&Omicron;"]   = utf8.codepointToUTF8(927)
http.htmlEntities["&omicron;"]   = utf8.codepointToUTF8(959)
http.htmlEntities["&oplus;"]     = utf8.codepointToUTF8(8853)
http.htmlEntities["&or;"]        = utf8.codepointToUTF8(8744)
http.htmlEntities["&ordf;"]      = utf8.codepointToUTF8(170)
http.htmlEntities["&ordm;"]      = utf8.codepointToUTF8(186)
http.htmlEntities["&Oslash;"]    = utf8.codepointToUTF8(216)
http.htmlEntities["&oslash;"]    = utf8.codepointToUTF8(248)
http.htmlEntities["&Otilde;"]    = utf8.codepointToUTF8(213)
http.htmlEntities["&otilde;"]    = utf8.codepointToUTF8(245)
http.htmlEntities["&otimes;"]    = utf8.codepointToUTF8(8855)
http.htmlEntities["&Ouml;"]      = utf8.codepointToUTF8(214)
http.htmlEntities["&ouml;"]      = utf8.codepointToUTF8(246)
http.htmlEntities["&para;"]      = utf8.codepointToUTF8(182)
http.htmlEntities["&part;"]      = utf8.codepointToUTF8(8706)
http.htmlEntities["&permil;"]    = utf8.codepointToUTF8(8240)
http.htmlEntities["&perp;"]      = utf8.codepointToUTF8(8869)
http.htmlEntities["&Phi;"]       = utf8.codepointToUTF8(934)
http.htmlEntities["&phi;"]       = utf8.codepointToUTF8(966)
http.htmlEntities["&Pi;"]        = utf8.codepointToUTF8(928)
http.htmlEntities["&pi;"]        = utf8.codepointToUTF8(960)
http.htmlEntities["&piv;"]       = utf8.codepointToUTF8(982)
http.htmlEntities["&plusmn;"]    = utf8.codepointToUTF8(177)
http.htmlEntities["&pound;"]     = utf8.codepointToUTF8(163)
http.htmlEntities["&prime;"]     = utf8.codepointToUTF8(8242)
http.htmlEntities["&Prime;"]     = utf8.codepointToUTF8(8243)
http.htmlEntities["&prod;"]      = utf8.codepointToUTF8(8719)
http.htmlEntities["&prop;"]      = utf8.codepointToUTF8(8733)
http.htmlEntities["&Psi;"]       = utf8.codepointToUTF8(936)
http.htmlEntities["&psi;"]       = utf8.codepointToUTF8(968)
http.htmlEntities["&radic;"]     = utf8.codepointToUTF8(8730)
http.htmlEntities["&raquo;"]     = utf8.codepointToUTF8(187)
http.htmlEntities["&rarr;"]      = utf8.codepointToUTF8(8594)
http.htmlEntities["&rceil;"]     = utf8.codepointToUTF8(8969)
http.htmlEntities["&rdquo;"]     = utf8.codepointToUTF8(8221)
http.htmlEntities["&reg;"]       = utf8.codepointToUTF8(174)
http.htmlEntities["&rfloor;"]    = utf8.codepointToUTF8(8971)
http.htmlEntities["&Rho;"]       = utf8.codepointToUTF8(929)
http.htmlEntities["&rho;"]       = utf8.codepointToUTF8(961)
http.htmlEntities["&rlm;"]       = utf8.codepointToUTF8(8207)
http.htmlEntities["&rsaquo;"]    = utf8.codepointToUTF8(8249)
http.htmlEntities["&rsquo;"]     = utf8.codepointToUTF8(8217)
http.htmlEntities["&sbquo;"]     = utf8.codepointToUTF8(8218)
http.htmlEntities["&Scaron;"]    = utf8.codepointToUTF8(352)
http.htmlEntities["&scaron;"]    = utf8.codepointToUTF8(353)
http.htmlEntities["&sdot;"]      = utf8.codepointToUTF8(8901)
http.htmlEntities["&sect;"]      = utf8.codepointToUTF8(167)
http.htmlEntities["&shy;"]       = utf8.codepointToUTF8(173)
http.htmlEntities["&Sigma;"]     = utf8.codepointToUTF8(931)
http.htmlEntities["&sigma;"]     = utf8.codepointToUTF8(963)
http.htmlEntities["&sigma;"]     = utf8.codepointToUTF8(963)
http.htmlEntities["&sigmaf;"]    = utf8.codepointToUTF8(962)
http.htmlEntities["&sim;"]       = utf8.codepointToUTF8(8764)
http.htmlEntities["&spades;"]    = utf8.codepointToUTF8(9824)
http.htmlEntities["&sub;"]       = utf8.codepointToUTF8(8834)
http.htmlEntities["&sube;"]      = utf8.codepointToUTF8(8838)
http.htmlEntities["&sum;"]       = utf8.codepointToUTF8(8721)
http.htmlEntities["&sup;"]       = utf8.codepointToUTF8(8835)
http.htmlEntities["&sup1;"]      = utf8.codepointToUTF8(185)
http.htmlEntities["&sup2;"]      = utf8.codepointToUTF8(178)
http.htmlEntities["&sup3;"]      = utf8.codepointToUTF8(179)
http.htmlEntities["&supe;"]      = utf8.codepointToUTF8(8839)
http.htmlEntities["&szlig;"]     = utf8.codepointToUTF8(223)
http.htmlEntities["&Tau;"]       = utf8.codepointToUTF8(932)
http.htmlEntities["&tau;"]       = utf8.codepointToUTF8(964)
http.htmlEntities["&there4;"]    = utf8.codepointToUTF8(8756)
http.htmlEntities["&Theta;"]     = utf8.codepointToUTF8(920)
http.htmlEntities["&theta;"]     = utf8.codepointToUTF8(952)
http.htmlEntities["&thetasym;"]  = utf8.codepointToUTF8(977)
http.htmlEntities["&thinsp;"]    = utf8.codepointToUTF8(8201)
http.htmlEntities["&THORN;"]     = utf8.codepointToUTF8(222)
http.htmlEntities["&thorn;"]     = utf8.codepointToUTF8(254)
http.htmlEntities["&tilde;"]     = utf8.codepointToUTF8(732)
http.htmlEntities["&times;"]     = utf8.codepointToUTF8(215)
http.htmlEntities["&trade;"]     = utf8.codepointToUTF8(8482)
http.htmlEntities["&Uacute;"]    = utf8.codepointToUTF8(218)
http.htmlEntities["&uacute;"]    = utf8.codepointToUTF8(250)
http.htmlEntities["&uarr;"]      = utf8.codepointToUTF8(8593)
http.htmlEntities["&Ucirc;"]     = utf8.codepointToUTF8(219)
http.htmlEntities["&ucirc;"]     = utf8.codepointToUTF8(251)
http.htmlEntities["&Ugrave;"]    = utf8.codepointToUTF8(217)
http.htmlEntities["&ugrave;"]    = utf8.codepointToUTF8(249)
http.htmlEntities["&uml;"]       = utf8.codepointToUTF8(168)
http.htmlEntities["&upsih;"]     = utf8.codepointToUTF8(978)
http.htmlEntities["&Upsilon;"]   = utf8.codepointToUTF8(933)
http.htmlEntities["&upsilon;"]   = utf8.codepointToUTF8(965)
http.htmlEntities["&Uuml;"]      = utf8.codepointToUTF8(220)
http.htmlEntities["&uuml;"]      = utf8.codepointToUTF8(252)
http.htmlEntities["&Xi;"]        = utf8.codepointToUTF8(926)
http.htmlEntities["&xi;"]        = utf8.codepointToUTF8(958)
http.htmlEntities["&Yacute;"]    = utf8.codepointToUTF8(221)
http.htmlEntities["&yacute;"]    = utf8.codepointToUTF8(253)
http.htmlEntities["&yen;"]       = utf8.codepointToUTF8(165)
http.htmlEntities["&yuml;"]      = utf8.codepointToUTF8(255)
http.htmlEntities["&Yuml;"]      = utf8.codepointToUTF8(376)
http.htmlEntities["&Zeta;"]      = utf8.codepointToUTF8(918)
http.htmlEntities["&zeta;"]      = utf8.codepointToUTF8(950)
http.htmlEntities["&zwj;"]       = utf8.codepointToUTF8(8205)
http.htmlEntities["&zwnj;"]      = utf8.codepointToUTF8(8204)

--- hs.http.registerEntity(entity, codepoint) -> string
--- Function
--- Registers an HTML Entity with the specified Unicode codepoint which can later referenced in your code as `hs.http.htmlEntity[entity]` for convenience and readability.
---
--- Parameters:
---  * entity -- The full text of the HTML Entity as it appears in HTML encoded documents.  A proper entity starts with & and ends with ; and entity labels which do not meet this will have them added -- future dereferences to get the corresponding UTF8 *must* include this initiator and terminator or they will not be recognized.
---  * codepoint -- a Unicode codepoint in numeric or `U+xxxx` format to register with as the given entity.
---
--- Returns:
---  * Returns the UTF8 byte sequence for the entity registered.
---
--- Notes:
---  * If an entity label was previously registered, this will overwrite the previous value with a new one.
---  * The return value is merely syntactic sugar and you do not need to save it locally; it can be safely ignored -- future access to the pre-converted entity should be retrieved as `hs.http.htmlEntities[entity]` in your code.  It looks good when invoked from the console, though ☺.
http.registerEntity = function(label, codepoint)
    local entity = label:match("^&?([^&;]+);?$")
    if not entity then
        return error("Invalid label '"..label.."' provided to hs.http.registerEntity", 2)
    else
        label = "&"..entity..";"
        http.htmlEntities[label] = utf8.codepointToUTF8(codepoint)
        return http.htmlEntities[label]
    end
end

--- hs.http.convertHtmlEntities(inString) -> outString
--- Function
--- Convert all recognized HTML Entities in the `inString` to appropriate UTF8 byte sequences and returns the converted text.
---
--- Parameters:
---  * inString -- A string containing any number of HTML Entities (&whatever;) in the text.
---
--- Returns:
---  * outString -- the input string with all recognized HTML Entity sequences converted to UTF8 byte sequences.
---
--- Notes:
---  * Recognized HTML Entities are those registered in `hs.http.htmlEntities` or numeric entity sequences: &#n; where `n` can be any integer number.
---  * This function is especially useful as a post-filter to data retrieved by the `hs.http.get` and `hs.http.asyncGet` functions.
http.convertHtmlEntities = function(input)
    return input:gsub("&[^;]+;", function(c) return http.htmlEntities[c] or c end)
end

--- hs.http.encodeForQuery(string) -> string
--- Function
--- Returns a copy of the provided string in which characters that are not valid within an HTTP query key or value are escaped with their %## equivalent.
---
--- Parameters:
---  * originalString - the string to make safe as a key or value for a query
---
--- Returns:
---  * the converted string
---
--- Notes:
---  * The intent of this function is to provide a valid key or a valid value for a query string, not to validate the entire query string.  For this reason, ?, =, +, and & are included in the converted characters.
local encodeForQuery = http.encodeForQuery
http.encodeForQuery = function(...)
    return (encodeForQuery(...):gsub("[%?=&+]", { ["?"] = "%3F", ["="] = "%3D", ["&"] = "%26", ["+"] = "%2B" } ))
end

-- Wrapper for legacy `hs.http.websocket(url, callback)`
-- This is undocumented, as `hs.http.websocket` was never originally exposed/documented.
local websocket = require("hs.websocket")
http.websocket = function(url, callback)
    return websocket.new(url, function(status, message)
        if type(callback) == "function" and status == "received" then
            return callback(message)
        end
    end)
end

return http
