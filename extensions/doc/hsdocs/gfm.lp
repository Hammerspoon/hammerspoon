<%
local HTML_HEAD = [[
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>]] .. cgilua.script_vpath .. [[</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th, td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; vertical-align: top; }
    </style>
    <link rel="stylesheet" href="]] .. cgilua.mkurlpath("docs.css") .. [[" type="text/css" media="screen" />
  </head>
  <body>
]]

local HTML_TAIL = [[
  </body>
</html>
]]

    local markdown    = require"hs.doc.markdown"
    local fs          = require"hs.fs"

    local virtualFile = (cgilua.script_vpath:sub(#cgilua.script_vpath) == "/") and (cgilua.script_vpath .. "index.md") or cgilua.script_vpath

    local relativeFile = cgilua.script_pdir:match("^(.*)/") .. virtualFile

    local f = io.open(relativeFile, "r")
    if f then
        if relativeFile:match("%.[mM][dD]$") then
            write(HTML_HEAD)
            write(markdown.convert(f:read("a")))
            write(HTML_TAIL)
        else
            local contentType = fs.fileUTI(relativeFile)
            if contentType then
                contentType = fs.fileUTIalternate(contentType, "mime")
            else
                contentType = "application/octet-stream"
            end
            cgilua.contentheader(contentType:match("^([^/]+)"), contentType:match("/([^/]+)$") or "")
            write(f:read("a"))
        end
        f:close()
    else
        write(HTML_HEAD)
        %><i>File <%= virtualFile %> not readable</i><%
        write(HTML_TAIL)
    end
%>
