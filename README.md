# Hammerspoon
[![Build Status](https://travis-ci.org/Hammerspoon/hammerspoon.svg?branch=master)](https://travis-ci.org/Hammerspoon/hammerspoon)

## What is Hammerspoon?

This is a tool for powerful automation of OS X. At its core, Hammerspoon is just a bridge between the operating system and a Lua scripting engine.
What gives Hammerspoon its power is a set of extensions that expose specific pieces of system functionality, to the user. With these, you can write Lua scripts to control many aspects of your OS X environment.

## How do I install it?

 * Visit:
  * https://github.com/Hammerspoon/hammerspoon/releases/latest or
 * Download the zip
 * Drag `Hammerspoon.app` from your `Downloads` folder to `Applications`

## How do I use it?

Hammerspoon is controlled by the config you write in ~/.hammerspoon/init.lua - you can place any Lua script you like in there, using the APIs that Hammerspoon provides. You can find API documentation and FAQs at http://www.hammerspoon.org/

If you need a reference for the Lua scripting language, see http://www.lua.org/docs.html

## How can I contribute?

More extensions will always be a huge benefit to Hammerspoon. They can either be pure Lua scripts that offer useful helper functions, or you can write Objective-C extensions to expose new areas of system functionality to users. For more information, see CONTRIBUTING.md

## Where can I get help?

You can usually get a quick answer in #hammerspoon on Freenode, or you can file an issue at https://github.com/Hammerspoon/hammerspoon/

## What is the history of the project?

Hammerspoon is a fork of (Mjolnir)[https://github.com/sdegutis/mjolnir] by Steven Degutis. Mjolnir aims to be a very minimal application, with its extensions hosted externally and managed using a Lua package manager. We felt that we wanted to take the project in a different direction to its maintainer, so the fork was born.

## What is the future of the project?

Our intentions for Hammerspoon broadly fall into these categories:
 * Ever wider coverage of system APIs in Extensions
 * Tighter integration between extensions
 * Smoother user experience (e.g. signed releases, easier access to documentation, easier discovery of extensions)
