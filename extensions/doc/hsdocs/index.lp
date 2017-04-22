<html>
<%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs.httpserver.hsminweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
<!-- <%= "--",">" %>

  <%
      cgilua.lp.include("common.lp")

      if cgilua.script_vpath ~= "/" then
          cgilua.redirect("module.lp" .. cgilua.script_vpath)
          return
      end

      local f = io.open("index.md")
      local indexMD = "<i>Header file, index.md, not present</i>"
      if f then
          indexMD = f:read("a")
          f:close()
      end

  %>

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="initial-scale=1" />
    <title>Hammerspoon docs</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th, td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; vertical-align: top; }
    </style>
    <link rel="stylesheet" href="<%= cgilua.mkurlpath("docs.css") %>" type="text/css" media="screen" />
  </head>

  <body>
    <header>
      <h1>Hammerspoon.app</h1>
    </header>
    <section><%= gfmConvert(indexMD) %></section>
    <section>
      <h3>API documentation</h3>
      <table class="api-documentation-overview">
        <% for i, mod in ipairs(documentation) do %>
          <tr>
            <td><a href="<%= cgilua.mkurlpath("module.lp/" .. mod.name) %>"><%= mod.name %></a></td>
            <td><%= gfmConvert(mod.desc) %></td>
          </tr>
        <% end %>
      </table>
    </section>
    <a name="spoons"></a>
    <section>
      <h3>Spoon documentation</h3>
      <table class="api-documentation-overview">
        <% for i, mod in ipairs(spoonDocumentation) do %>
          <tr>
            <td><a href="<%= cgilua.mkurlpath("module.lp/spoon." .. mod.name) %>"><%= mod.name %></a></td>
            <td><%= gfmConvert(mod.desc) %></td>
          </tr>
        <% end %>
      </table>
    </section>
  </body>

<%= "<","!--" %> -->
</html>
