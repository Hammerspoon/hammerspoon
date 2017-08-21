
<!-- ok, misnamed... everything for the built-in browser only goes here -->

<% if hsminweb.request.headers["User-Agent"]:match("Hammerspoon/[%d%.]+$") then %>

<%
    local invertLevel = settings.get("_documentationServer.invertDocs")
    if type(invertLevel) == "nil" then invertLevel = (require"hs.host".interfaceStyle() == "Dark") end
    if type(invertLevel) == "boolean" then invertLevel = invertLevel and 100 or 0 end
    require("hs.doc").hsdocs._browser:darkMode(invertLevel > 50)
%>

<style type="text/css">
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

<%
  local translation = "translateY(-50%)"
  if settings.get("_documentationServer.entitiesInSidebar") and cgilua.script_file == "module.lp" then
      translation = translation .. " translateX(-10vw)"
  end
%>

  div.helpScreen {
    display: none;
    position: fixed;
    top: 50%;
    -webkit-transform: <%= translation .. ";" %>
    -ms-transform: <%= translation .. ";" %>
    transform: <%= translation .. ";" %>
    margin-left: auto ;
    margin-right: auto ;
    width: 80%;
    padding: 20px;
    background-color: #ccc;
    border-radius: 10px;
    border-style: solid;
    border-width: medium;
  }
</style>

<div class="searchbar" id="searcher">
    <span class="searchcontrols">
        <a href="javascript:searchForText(1)">⌘⇧-G prev</a>
        &nbsp;<input type="text" id="query" placeholder="enter search term" onfocusin="editingSearcher = true;" onfocusout="editingSearcher = false;"/>&nbsp;
        <a href="javascript:searchForText(0)">⌘-G next</a>
    </span>
</div>

<div class="helpScreen" id="helpStuff">
  <h4 style="margin:0">Using the builtin Hammerspoon Documentation Browser<h4>
  <section>
    <h5>Toolbar Icons</h5>
    <table>
<%
    local doc = require("hs.doc")
    local tb  = doc.hsdocs._browser:attachedToolbar()
    local tbitems = tb:items()
    local tbimages = {}
    for _, v in ipairs(tbitems) do
      if not v:match("^NS") then
        local tbdt = tb:itemDetails(v)
        if v == "search" then %>
          <tr><th><i>🔍 Search</i></th><td><%= tbdt.tooltip %></td></tr>
        <% elseif v == "navigation" then %>
          <tr><th><img height="20" width="20" src="<%= tbdt.subitems[1].image:setSize{ h = 20, w = 20 }:encodeAsURLString() %>">&nbsp;<img height="20" width="20" src="<%= tbdt.subitems[2].image:setSize{ h = 20, w = 20 }:encodeAsURLString() %>"></th><td><%= tbdt.subitems[1].tooltip .. "/" .. tbdt.subitems[2].tooltip %></td></tr>
        <% else %>
          <tr><th><img height="20" width="20" src="<%= tbdt.image:setSize{ h = 20, w = 20 }:encodeAsURLString() %>"></th><td><%= tbdt.tooltip %></td></tr>
      <% end
      end
    end
%>
    </table>
  </section>
  <section>
    <h5>Keyboard Shortcuts</h5>
    <table>
      <tr><th>⌘F</th><td>Toggle the "Find in page" search box.  Close by typing ⌘-F or typing the Escape key.</td></tr>
      <tr><th>⌘⇧G</th><td>When the "Find in page" search box is visible, will search for the previous occurrence of the search term in the current page. You may also use ⇧-Enter.</td></tr>
      <tr><th>⌘G</th><td>When the "Find in page" search box is visible, will search for the next occurrence of the search term in the current page. You may also use Enter.</td></tr>
      <tr><th>⌘L</th><td>Focus the search field at the top of the page so you can type in a module to jump to</td></tr>
      <tr><th>⌘R</th><td>Reload the current page.</tr>
      <tr><td colspan="2">When neither the "Find in page" search box or this help are visible, the Escape key will close this documentation viewer.</td></tr>
    </table>
  </section>
</div>

<script type="text/javascript">
  function toggleHelp(state) {
      if (state == null) {
          state = !(document.getElementById("helpStuff").style.display == "block");
      }
      if (state) {
        document.getElementById("helpStuff").style.display = "block";
      } else {
        document.getElementById("helpStuff").style.display = "none";
      }
  }

  function searchForText(direction) {
      var ele = document.getElementById('query') ;
      var result = window.find(ele.value, 0, direction, 1) ;
      editingSearcher = (ele.selectionEnd != 0) ;
      return result ;
  }

  function toggleFind(state) {
      if (state == null) {
          state = !(document.getElementById("searcher").style.display == "block");
      }
      if (state) {
        document.getElementById("searcher").style.display = "block";
        var ele = document.getElementById('query') ;
        ele.focus();
        ele.selectionStart = 0;
        ele.selectionEnd = ele.value.length;
        editingSearcher = true ;
      } else {
        if (editingSearcher) {
          document.getElementById("searcher").style.display = "none";
        } else {
          var ele = document.getElementById('query') ;
          ele.focus();
          ele.selectionStart = 0;
          ele.selectionEnd = ele.value.length;
          editingSearcher = true ;
        }
      }
  }

// not used anymore, but just in case, I'm leaving the skeleton here...
//   function sendToHammerspoon(msg) {
//       try {
//           webkit.messageHandlers.hsdocs.postMessage(msg);
//       } catch(err) {
//           console.log('The controller does not exist yet');
//       }
//   }

// most keys are handled by Hammerspoon with hs.hotkey.modal; allowing enter to find next/prev there would
// prevent its use elsewhere (i.e. search field in toolbar, forms if we ever add them, etc.

  function KeyPressHappened(e) {
//     console.log(e) ;
    if (document.getElementById("searcher").style.display == "block") {
      if (e.keyCode == 13 && !e.altKey && !e.ctrlKey) { // allow [shift] enter to find prev/next
        searchForText(e.shiftKey ? 1 : 0) ;
        return false ;
      }
      return true ;
    }
    return true ;
  }

  // see common.lp for "good enough" version of addEvent
  addEvent(document, "keypress", KeyPressHappened);
</script>

<% end %>
