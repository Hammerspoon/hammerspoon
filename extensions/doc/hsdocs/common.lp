<%

    local doc = require("hs.doc")

    -- the following are defined as global because new "global" variables are actually stored in
    -- the template's _ENV, rather than in _G, so it's still local to the building of the page
    -- which includes this template.

    settings = require("hs.settings")
    documentation      = doc._jsonForModules
    spoonDocumentation = doc._jsonForSpoons

    -- used to apply markdown to html conversion for text
    gfmConvert = function(theText)
        return require"hs.doc.markdown".convert(theText)
    end

    -- inversion mode option for night time, dark mode, etc. similar to Dash.  By default, follows
    -- system interface mode
    local invertLevel = settings.get("_documentationServer.invertDocs")
    if not ({ ["number"] = 1, ["boolean"] = 1 })[type(invertLevel)] then
        invertLevel = (require"hs.host".interfaceStyle() == "Dark")
    end
    if type(invertLevel) == "boolean" then
        invertLevel = invertLevel and 100 or 0
    end

%>

<script type="text/javascript">
  // modified from code at http://stackoverflow.com/a/18990842
  var setInvertLevel = function (level) {
    var css = 'html {-webkit-filter: invert(' + level + '%);' + '-moz-filter: invert(' + level + '%);' + '-o-filter: invert(' + level + '%);' + '-ms-filter: invert(' + level + '%); }';
    var head = document.getElementsByTagName('head')[0];
    var style = document.createElement('style');

    style.type = 'text/css';
    if (style.styleSheet) {
      style.styleSheet.cssText = css;
    } else {
      style.appendChild(document.createTextNode(css));
    }
    head.appendChild(style);
  }

  // see http://austinmatzko.com/2008/04/14/addevent-preserving-this/
  var addEvent = function( obj, type, fn ) {
    if (obj.addEventListener)
      obj.addEventListener(type, fn, false);
    else if (obj.attachEvent)
      obj.attachEvent('on' + type, function() { return fn.apply(obj, new Array(window.event));});
  }

  addEvent(window, 'load', function() { setInvertLevel(<%= invertLevel %>); } );
</script>

<link rel="stylesheet" href="<%= cgilua.mkurlpath("docs.css") %>" type="text/css" media="screen" />
<style type="text/css">
  h1 { margin:0; }
</style>
