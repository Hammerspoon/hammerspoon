<html>
<%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs.httpserver.hsminweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
<!-- <%= "--",">" %>

  <%
      cgilua.lp.include("common.lp")

      local modNames = {}
      for i, v in ipairs(documentation) do
          modNames[v.name] = true
      end
      for i,v in ipairs(spoonDocumentation) do
          modNames["spoon." .. v.name] = true
      end

      -- the following code looks for the module to display as either part of URL PATH_INFO or as a
      -- query item.  The following URLs are supported:

      --  * http://server:port/.../module.lp?q=<module>
      --  * http://server:port/.../module.lp/<module>

      -- The following will also "jump" to the specified function in the rendered output
      --  * http://server:port/.../module.lp?q=<module>.<function>
      --  * http://server:port/.../module.lp/<module>/<function>
      --  * http://server:port/.../module.lp/<module>.<function>

      -- allow /module[/function] at end of URL
      local lookingFor, jumpTo = cgilua.script_vpath:match("^/([^/]*)/?([^/]*)$")
      if (not lookingFor or lookingFor == "") and cgilua.QUERY.q then
      -- allow ?q=module[.function] at end of URL (standard GET query)
          lookingFor = cgilua.QUERY.q
      end
      if not modNames[lookingFor] then
          -- if not found, try without html extension (this is used in some places to link to another module in the Dash docs
          if modNames[lookingFor:gsub("%.html$", "")] then
              lookingFor = lookingFor:gsub("%.html$", "")
          elseif not jumpTo or jumpTo == "" then
          -- otherwise, assuming no existing function portion, try treating the last item of the module name as the function portion
              local p1, p2 = lookingFor:match("^(.+)[%.:]([^%.:]*)$")
              if modNames[p1] then
                  lookingFor, jumpTo = p1, p2
              end
          end
      end

      local isSpoon = false
      local mod = {
          desc = "Module documentation not found",
          doc = "Module documentation not found\n\nThe requested module does not appear to have any documentation in the set available to this web site.",
          items = {},
          name = lookingFor or "** no module specified **"
      }
      if lookingFor then
          if lookingFor:match("^spoon%.") then
              isSpoon = true
              local target = lookingFor:match("^spoon%.(.+)$")
              for i, v in ipairs(spoonDocumentation) do
                  if v.name == target then
                      mod = v
                      break
                  end
              end
          else
              for i, v in ipairs(documentation) do
                  if v.name == lookingFor then
                      mod = v
                      break
                  end
              end
          end
      end

      if jumpTo ~= "" then %>
        <script type="text/javascript">
          addEvent(window, 'load', function() {
            var top = document.getElementById('<%= jumpTo %>').offsetTop;
            window.scrollTo(0, top);
          });
        </script>
  <%  end %>

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="initial-scale=1" />
    <title>Hammerspoon docs: <%= mod.name %> module</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th { background-color: #DDDDDD; vertical-align: top; padding: 3px; }
      td { width: 100%; background-color: #EEEEEE; vertical-align: top; padding: 3px; }
      table { width: 100% ; border: 1px solid #0; text-align: left; }
      section > table table td { width: 0; }

<% if settings.get("_documentationServer.entitiesInSidebar") then %>
/* Inspired by https://openuserjs.org/scripts/krasnovpro/hammerspoon.org_Documentation/source */
      header+h3 {
        display: none;
      }
      header+h3+ul {
        height: 100%;
        left: 0;
        list-style: none;
        overflow-y: scroll;
        padding: 10px 15px;
        position: fixed;
        top: 10px;
        width: 20vw;
      }

      header+h3+ul * {
        font-size: .8rem;
      }

      header+h3+ul ul {
        list-style: none;
        margin: .2rem 0 1rem 0;
        padding: 0;
      }

      header+h3+ul ul li {
        font-size: .8rem;
        line-height: 1.5;
        padding: 0;
      }
      body {
        margin-left: 20vw;
        width: 75vw;
      }
<% end %>
    </style>
  </head>

  <body>
    <header>
      <h1><a href="<%= cgilua.mkurlpath("index.lp") .. (isSpoon and "?q=Spoons" or "") %>"><%= (isSpoon and "spoon" or "docs") %></a> &raquo; <%= mod.name %></h1>
      <%= gfmConvert(mod.doc) %>
    </header>
    <h3>API Overview</h3>
    <ul>
      <%
        if mod.name ~= "hs" then
            local submodules = {}
            local relevantJson = isSpoon and spoonDocumentation or documentation
            for _, v in ipairs(relevantJson) do
                if v.name:match("^" .. mod.name .. "%.") then table.insert(submodules, v.name) end
            end

            if #submodules > 0 then %>
                <li>Submodules</li>
                <ul>
                  <% for _, item in ipairs(submodules) do %>
                      <li><a href="<%= cgilua.mkurlpath("module.lp/" .. (isSpoon and "spoon." or "") .. item) %>"><%= item %></a></li>
                  <% end %>
                </ul>
          <% end
        end

        local sectionorder = { "Deprecated", "Command", "Constant", "Variable", "Function", "Constructor", "Field", "Method" }
        local sectiondetails = {
          ["Deprecated"]  = "API features which will be removed in an upcoming release",
          ["Command"]     = "External shell commands",
          ["Constant"]    = "Useful values which cannot be changed",
          ["Variable"]    = "Configurable values",
          ["Function"]    = "API calls offered directly by the extension",
          ["Constructor"] = "API calls which return an object, typically one that offers API methods",
          ["Field"]       = "Variables which can only be accessed from an object returned by a constructor",
          ["Method"]      = "API calls which can only be made on an object returned by a constructor",
        }

        local activeSections = {}

        for _, section in ipairs(sectionorder) do
          local items = {}
          for _, moditem in ipairs(mod.items) do
            if moditem["type"] == section then table.insert(items, moditem) end
          end
          table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
          if #items > 0 then
            table.insert(activeSections, { name = section, items = items }) %>
            <li><%= section %>s - <%= sectiondetails[section] %></li>
            <ul>
              <% for _, item in ipairs(items) do %>
                  <li><a href="#<%= item.name %>"><%= item.name %></a></li>
              <% end %>
            </ul>
          <% end
        end
      %>
    </ul>
    <h3>API Documentation</h3>
    <%
      for _, section in ipairs(activeSections) do %>
        <h4 class="documentation-section"><%= section.name %>s</h4>
        <% for _, item in ipairs(section.items) do %>
          <section id="<%= item.name %>">
          <a name="//apple_ref/cpp/<%= item['type'] %>/<%= item.name %>" class="dashAnchor"></a>
          <h5><a href="#<%= item.name %>"><%= item['name'] %></a></h5>
          <table>
            <tr>
              <th>Signature</td>
              <td><code><%= item.def %></code></td>
            </tr>
            <tr>
              <th>Type</td>
              <td><%= item.type %></td>
            </tr>
            <tr>
              <th>Description</td>
              <td>
                <%= gfmConvert(item.doc) %>
              </td>
            </tr>
          </table>
          </section>
        <% end
      end
    %>
  <% cgilua.lp.include("search.lp") %>
  </body>

<%= "<","!--" %> -->
</html>
