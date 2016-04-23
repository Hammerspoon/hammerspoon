<head>
  <title>Lua Template Test</title>
</head>

<!--<%

    -- the trick of prefacing code blocks with <!-- and finishing them with --> keeps output
    -- relatively minor if template support is not enabled for the web server -- it is not
    -- necessary

    local inspect = require("hs.inspect")
    local http    = require("hs.http")

    -- overkill; usually it's sufficient to just do :gsub("<", "&lt;"):gsub(">", "&gt;")
    -- but this shows how to be thorough if you truly are unsure what to expect

    local makeHTMLSafe = function(inputString)
        -- gotta do & first or it screws up the other entities
        inputString = inputString:gsub("&", "&amp;")
        for k, v in pairs(http.htmlEntities) do
            if k ~= "&amp;" then inputString = inputString:gsub(v, k) end
        end
        return inputString
    end

    -- an example of defining a "global" variable... it should show up in the output of _ENV in
    -- the rendered output of the page.

    i_am_global = "to the template, but not Hammerspoon"

    -- the line after <body> prints a reasonably clean error message to the browser if template
    -- support is not enabled, but is suppressed if it is.  As with the bracketing of lua
    -- code blocks with the HTML comment tags, it is not necessary for this to work.

%>-->

<body>
<%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs.httpserver.hsminweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
<!-- <%= "--",">" %>

<b>_ENV overview</b>
<pre><%= makeHTMLSafe(inspect(_ENV, {depth = 1})) %></pre>
<hr>
<b>CGILua Helper Table</b>
<pre><%= makeHTMLSafe(inspect(cgilua)) %></pre>
<hr>
<b>hsminweb Helper Variable</b>
<pre><%= makeHTMLSafe(inspect(hsminweb)) %></pre>
<hr>
<div align="right"><i><%= os.date() %></i></div>

<%= "<","!--" %> -->
</body>

