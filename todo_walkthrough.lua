-- show an alert to let you know Hydra's running
hydra.alert("Hydra sample config loaded", 1.5)

-- open a repl with mash-R; requires https://github.com/sdegutis/hydra-cli
hotkey.bind({"cmd", "ctrl", "alt"}, "R", repl.open)

-- move the window to the right half of the screen
function movewindow_righthalf()
  local win = window.focusedwindow()
  local newframe = win:screen():frame_without_dock_or_menu()
  newframe.w = newframe.w / 2
  newframe.x = newframe.x + newframe.w -- comment out this line to push it to left half of screen
  win:setframe(newframe)
end

-- bind your custom function to a convenient hotkey
-- note: it's good practice to keep hotkey-bindings separate from their functions, like we're doing here
hotkey.new({"cmd", "ctrl", "alt"}, "L", movewindow_righthalf):enable()
