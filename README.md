# Hammerspoon

[![Build Status](https://travis-ci.org/Hammerspoon/hammerspoon.svg?branch=master)](https://travis-ci.org/Hammerspoon/hammerspoon)
[![codecov.io](https://codecov.io/github/Hammerspoon/hammerspoon/coverage.svg?branch=master)](https://codecov.io/github/Hammerspoon/hammerspoon?branch=master)
[![Downloads current release](https://img.shields.io/github/downloads/Hammerspoon/hammerspoon/latest/total.svg)](https://github.com/Hammerspoon/hammerspoon/releases)
[![Downloads all releases](https://img.shields.io/github/downloads/Hammerspoon/hammerspoon/total.svg?maxAge=2592000)](https://github.com/Hammerspoon/hammerspoon/releases)
[![Latest tag](https://img.shields.io/github/tag/Hammerspoon/hammerspoon.svg)](https://github.com/Hammerspoon/hammerspoon/tags)
[![Latest release](https://img.shields.io/github/release/Hammerspoon/hammerspoon.svg)](https://github.com/Hammerspoon/hammerspoon/releases/latest)
[![Dependency Status](https://www.versioneye.com/user/projects/58ecbecbd6c98d0043fec94d/badge.svg?style=flat-square)](https://www.versioneye.com/user/projects/58ecbecbd6c98d0043fec94d)

## What is Hammerspoon?

This is a tool for powerful automation of OS X. At its core, Hammerspoon is just a bridge between the operating system and a Lua scripting engine.

What gives Hammerspoon its power is a set of extensions that expose specific pieces of system functionality, to the user. With these, you can write Lua scripts to control many aspects of your OS X environment.

## How do I install it?

 * Download the [latest release](https://github.com/Hammerspoon/hammerspoon/releases/latest)
 * Drag `Hammerspoon.app` from your `Downloads` folder to `Applications`


## Quickstart

Out of the box, Hammerspoon does nothing.
You will need to create a Lua script in `~/.hammerspoon/init.lua` using our APIs and standard Lua APIs.
You can learn more about the Lua scripting language at [Lua website](https://lua.org).

Good first step is to make `Hello world` program for yourself as explained
here: https://www.hammerspoon.org/go/#helloworld

For practical examples, see our Wiki: https://github.com/Hammerspoon/hammerspoon/wiki
Section "Sample-Configurations" shows some real-world scenarios.

## Resources

We have:

- [Getting Started Guide](http://www.hammerspoon.org/go/)
- extensive [API docs](http://www.hammerspoon.org/docs/)
- [FAQ](http://www.hammerspoon.org/faq/)
- [Contribution Guide](https://github.com/Hammerspoon/hammerspoon/blob/master/CONTRIBUTING.md) for developers looking to get involved

## Community

**IRC**

- General chat/support/development happen on `#hammerspoon` channel on Freenode
- Searchable archive for the channel: https://botbot.me/freenode/hammerspoon/

**Google Groups**

- https://groups.google.com/forum/#!forum/hammerspoon/

## What is the history of the project?

Hammerspoon is a fork of [Mjolnir](https://github.com/sdegutis/mjolnir) by Steven Degutis. Mjolnir aims to be a very minimal application, with its extensions hosted externally and managed using a Lua package manager. We wanted to provide a more integrated experience.

## What is the future of the project?

Our intentions for Hammerspoon broadly fall into these categories:
 * Ever wider coverage of system APIs in Extensions
 * Tighter integration between extensions
 * Smoother user experience
