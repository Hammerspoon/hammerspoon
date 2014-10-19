# Hammerspoon

## What is Hammerspoon?

This is a tool for powerful automation of OS X. At its core, Hammerspoon is just a bridge between the operating system and a Lua scripting engine.
What gives Hammerspoon its power is a set of extensions that expose specific pieces of system functionality, to the user.

## How do I install it?

Grab the latest release from the github releases page, or use the download button on http://www.hammerspoon.org/ then drag the application to `/Applications/`.

## How do I use it?

While we intend Hammerspoon to be minimally useful out of the box, the real appeal is being able to write your own Lua code to orchestrate your desktop. To do this, edit `~/.hammerspoon/init.lua` with reference to the extensions available in Hammerspoon. Documentation for the APIs exposed by the extensions can be found at http://www.hammerspoon.org/docs/

If you need a reference for the Lua scripting language, see http://www.lua.org/docs.html

## How can I contribute?

More extensions will always be a huge benefit to Hammerspoon. They can either be pure Lua scripts that offer useful helper functions, or you can write Objective-C extensions to expose new areas of system functionality to users. For more information, see CONTRIBUTING.md

## Where can I get help?

You can usually get a quick answer in #hammerspoon on Freenode, or you can file an issue at https://github.com/Hammerspoon/hammerspoon/

