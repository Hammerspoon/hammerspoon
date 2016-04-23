<%

    -- gfmConvert, documentationSourceTag, and documentation are "global" because this template is
    -- included by both index.lp and module.lp; new "global" variables are actually stored in the
    -- template's _ENV, rather than in _G

    -- only read and convert the json data once
    if not hs._docsAsArray then
        local input = io.open(hs.docstrings_json_file, "rb")
        -- we may add support for inserting third party docs in the future, so add a label
        -- specifying the documentation source
        hs._docsAsArray = {
            from = "Core JSON",
            docs = require"hs.json".decode(input:read("a")),
        }
        input:close()
    end
    documentationSourceTag, documentation = hs._docsAsArray.from, hs._docsAsArray.docs

    -- used to apply markdown to html conversion for text
    gfmConvert = function(theText)
        return require"hs.doc.markdown".convert(theText)
    end

    -- inversion mode option for night time, dark mode, etc. similar to Dash.  By default, follows
    -- system interface mode
    local invertLevel = require"hs.settings".get("_hsminWeb.invertDocs")
    if type(invertLevel) == "nil" then
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
