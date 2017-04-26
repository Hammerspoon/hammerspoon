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
</style>

<div class="searchbar" id="searcher">
    <span class="searchcontrols">
        <a href="javascript:searchForText(1)">⌘⇧-G prev</a>
        &nbsp;<input type="text" id="query" placeholder="enter search term"/>&nbsp;
        <a href="javascript:searchForText(0)">⌘-G next</a>
    </span>
</div>

<script type="text/javascript">
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

  // see common.lp for "good enough" version of addEvent
  addEvent(document, "keypress", KeyPressHappened);
</script>
