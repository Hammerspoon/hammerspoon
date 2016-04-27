<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title><%= cgilua.script_vpath %></title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th, td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; vertical-align: top; }
    </style>
    <link rel="stylesheet" href="<%= cgilua.mkurlpath("docs.css") %>" type="text/css" media="screen" />
  </head>

  <body>
<%
    local markdown = require"hs.doc.markdown"
    local virtualFile = (cgilua.script_vpath:sub(#cgilua.script_vpath) == "/") and (cgilua.script_vpath .. "index.md") or cgilua.script_vpath

    local file = cgilua.script_pdir:match("^(.*)/") .. virtualFile

    local f = io.open(file, "r")
    if f then
        write(markdown.convert(f:read("a")))
        f:close()
    else %>
        <i>File <%= virtualFile %> not readable</i>
<%  end
%>
  </body>
</html>