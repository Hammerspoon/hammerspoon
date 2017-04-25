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

      local defaultTarget = cgilua.QUERY.q or "API"
  %>

  <!-- Tabbed sections code is a variant on https://www.w3schools.com/howto/howto_js_tabs.asp -->

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="initial-scale=1" />
    <title>Hammerspoon docs</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th, td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; vertical-align: top; }

      /* Style the tab */
      div.tab {
          overflow: hidden;
          border: 1px solid #ccc;
          background-color: #f1f1f1;
      }

      /* Style the buttons inside the tab */
      div.tab button {
          background-color: inherit;
          font-size: 16px;
          float: left;
          border: none;
          outline: none;
          cursor: pointer;
          padding: 14px 16px;
          transition: 0.3s;
      }

      /* Change background color of buttons on hover */
      div.tab button:hover {
          background-color: #ddd;
      }

      /* Create an active/current tablink class */
      div.tab button.active {
          background-color: #ccc;
      }

      /* Style the tab content */
      .tabcontent {
          display: none;
      }

    </style>
    <link rel="stylesheet" href="<%= cgilua.mkurlpath("docs.css") %>" type="text/css" media="screen" />
    <style type="text/css">
      h1 { margin:0; }
      div.searchbar {
        display: none;
        top: 0;
        left: 0;
        width: 100%;
        text-align: right;
        position: fixed;
        padding: 5px;
      }
      span.searchcontrols {
        background-color: #ccc;
        padding: 10px;
        border-radius: 10px;
      }
      span.searchcontrols a {
        font-size: .8rem;
        font-style: italic;
      }
      ::-webkit-input-placeholder {
         font-style: italic;
      }
      :-moz-placeholder {
         font-style: italic;
      }
      ::-moz-placeholder {
         font-style: italic;
      }
      :-ms-input-placeholder {
         font-style: italic;
      }
    </style>

    <script type="text/javascript">
      function openTab(evt, cityName) {
          // Declare all variables
          var i, tabcontent, tablinks;

          // Get all elements with class="tabcontent" and hide them
          tabcontent = document.getElementsByClassName("tabcontent");
          for (i = 0; i < tabcontent.length; i++) {
              tabcontent[i].style.display = "none";
          }

          // Get all elements with class="tablinks" and remove the class "active"
          tablinks = document.getElementsByClassName("tablinks");
          for (i = 0; i < tablinks.length; i++) {
              tablinks[i].className = tablinks[i].className.replace(" active", "");
          }

          // Show the current tab, and add an "active" class to the button that opened the tab
          document.getElementById(cityName).style.display = "block";
          evt.currentTarget.className += " active";
      }
    </script>

  </head>

  <body>
    <div class="searchbar" id="searcher">
        <span class="searchcontrols">
            <a href="javascript:searchForText(1)">⌘⇧-G prev</a>
            &nbsp;<input type="text" id="query" placeholder="enter search term"/>&nbsp;
            <a href="javascript:searchForText(0)">⌘-G next</a>
        </span>
    </div>
    <header>
      <h1>Hammerspoon.app</h1>
    </header>
    <section><%= gfmConvert(indexMD) %></section>

    <br>
    <div class="tab">
    <% for i,label in ipairs({ "API", "Spoons" }) do
        if label == defaultTarget then %>
          <button class="tablinks" onclick="openTab(event, '<%= label %>')" id="defaultOpen"><%= label %></button>
      <% else %>
          <button class="tablinks" onclick="openTab(event, '<%= label %>')"><%= label %></button>
      <% end
    end %>
    </div>

    <div id="API" class="tabcontent">
      <h3>API documentation</h3>
      <table class="api-documentation-overview">
        <% for i, mod in ipairs(documentation) do %>
          <tr>
            <td><a href="<%= cgilua.mkurlpath("module.lp/" .. mod.name) %>"><%= mod.name %></a></td>
            <td><%= gfmConvert(mod.desc) %></td>
          </tr>
        <% end %>
      </table>
    </div>

    <div id="Spoons" class="tabcontent">
      <h3>Spoon documentation</h3>
      <table class="api-documentation-overview">
        <% for i, mod in ipairs(spoonDocumentation) do %>
          <tr>
            <td><a href="<%= cgilua.mkurlpath("module.lp/spoon." .. mod.name) %>"><%= mod.name %></a></td>
            <td><%= gfmConvert(mod.desc) %></td>
          </tr>
        <% end %>
      </table>
    </div>

  </body>

  <script type="text/javascript">
    // Get the element with id="defaultOpen" and click on it
    document.getElementById("defaultOpen").click();

    function searchForText(direction) {
        return window.find(document.getElementById('query').value, 0, direction, 1) ;
    }

    function KeyPressHappened(e) {
//       console.log(e) ;
      code = e.keyCode ;
      if ((code == 102) && e.metaKey) { // Cmd-F
          if (document.getElementById("searcher").style.display == "block") {
              document.getElementById("searcher").style.display = "none" ;
          } else {
              document.getElementById("searcher").style.display = "block" ;
              document.getElementById('query').focus()
          }
      } else if (document.getElementById("searcher").style.display == "block") {
          if ((code == 13 || (code == 103 && e.metaKey)) && e.shiftKey) {         // Shift-enter or Cmd-Shift-G
            searchForText(1) ;
          } else if ((code == 13 || (code == 103 && e.metaKey)) && !e.shiftKey) { // enter or Cmd-G
             searchForText(0) ;
          } else {
            return true ;
          }
      } else {
          return true ;
      }
      return false ;
    }
    document.onkeypress = KeyPressHappened;
  </script>

<%= "<","!--" %> -->
</html>
