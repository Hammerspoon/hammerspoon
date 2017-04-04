# A guide for creating and distributing Hammerspoon Spoons

## What is a Spoon?

Spoons are intended to be pure-Lua plugins for users to use in their Hammerspoon configs.

As a community, we have created many great configurations for Hammerspoon, but sharing code between them is hard and fragile. Spoons have been created as a way to address these issues.
Users should be able to download a Spoon and quickly integrate it into their config without worrying about what it is doing internally.

This is possible because of two things:

 * Infrastructure within Hammerspoon for loading Lua code from Spoons
 * The authors of Spoons sticking, wherever possible, to a standard API for users to use

## Where do I get Spoons from?

The official repository of Spoons is [https://github.com/Hammerspoon/Spoons](https://github.com/Hammerspoon/Spoons), but authors may choose to distribute them separately from their own sites.

## How do I install a Spoon?

Spoons should be distributed as `.zip` files. Simply download one, uncompress it (if your browser hasn't done that part automatically) and double click on the Spoon. Hammerspoon will install it for you in `~/.hammerspoon/Spoons/`

## How do I use a Spoon?

There are two parts to this, loading the spoon, and integrating it into your configuration.
Hopefully the Spoon came with some documentation, so look in `~/.hammerspoon/Spoons/NAME.spoon`. There you should find some documentation of the API offered by the Spoon, and any special requirements it has.

### Loading a Spoon

For most Spoons, simply add `hs.loadSpoon(NAME)` to your Hammerspoon config (note that `NAME` should *not* include the `.spoon` extension). This will make the spoon available in the global Lua namespace as `NAME`.

### Integrating into your configuration

In most cases, the API should take roughly this form:

 * `NAME:init()` - this is called automatically by `hs.loadSpoon()` and will do any initial setup work required, but should generally not start taking any actions
 * `NAME:start()` - if any kind of background work is necessary, this method will start it
 * `NAME:stop()` - if any kind of background work is running, this method will stop it
 * `NAME:bindHotkeys(mapping)` - this method is used to tell the Spoon how to bind hotkeys for its various functions. It should accept a single argument, a table in the form:

```lua
  { someFeature: {{"cmd", "alt"}, "f"},
    otherFeature: {{"shift", "ctrl"}, "b"}}
```

The Spoon should also provide some standard metadata:

 * `NAME.name` - A string containing the name of the Spoon
 * `NAME.version` - A string containing the version number of the Spoon
 * `NAME.author` - A string containing the name/email of the spoon's author

and optionally:

 * `NAME.homepage` - A string containing a URL to the Spoon's homepage

Many Spoons will offer additional API points on top of these, and you should consult their documentation to learn more.

