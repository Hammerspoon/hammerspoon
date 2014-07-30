--- === repl ===
---
--- The REPL (Read-Eval-Print-Loop) is excellent for exploring and experiment with Hydra's API.
---
--- It has all of the familiar readline-like keybindings, including C-b, C-f, M-b, M-f, etc; use C-p and C-n to browse command history.
---
--- Type `help` in the REPL for info on how to use the documentation system.

repl = {}

--- repl.open()
--- Opens a new REPL.
--- In beta versions of Hydra, the REPL was a textgrid; in Hydra 1.0, this function now opens hydra-cli; see https://github.com/sdegutis/hydra-cli
--- When hydra-cli is installed, this function opens it in a new terminal window; see repl.path.
--- When it's not installed, this function opens the github page for hydra-cli which includes installation instructions, as a convenience to the user.
--- NOTE: This seems to not work when you're using Bash version 4. In this case, you can use something like this intead:
---     os.execute([[osascript -e 'tell application "Terminal" to do script "/usr/local/bin/hydra" in do script ""']])
function repl.open()
  if not os.execute('open "' .. repl.path .. '"') then
    hydra.alert('To use the REPL, install hydra-cli; see the opened website for installation instructions.', 10)
    os.execute('open https://github.com/sdegutis/hydra-cli')
  end
end

--- repl.path -> string
--- The path to the hydra-cli binary; defaults to "/usr/local/bin/hydra"
repl.path = "/usr/local/bin/hydra"
