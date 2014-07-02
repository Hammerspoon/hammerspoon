require 'json'
require 'erb'

template = ERB.new(File.read("template.erb"))
system("mkdir -p docs && rm -f docs/api*html")

groups = JSON.load(File.read("hydra.json"))
groups.each do |group|
  File.write("docs/#{group['name']}.html", template.result(binding))
end

group = {}
group['name'] = "<root>"
group['doc'] = <<END
Hydra documenetation.

### Some definitions

When we say a function returns a `window` or `hotkey`, we're really
talking about a Lua table that represents these things. You're free to
set any keys on it that you please. The only rule is that Hydra is
free to store keys on them that start with an underscore for its
internals, so don't use an underscore.

Much of the Hydra API takes a few geometrical types, like `point`,
`size`, and `rect`. These are just tables. Points have keys x and y,
sizes have keys w and h, and rects have all four keys. So you could
use a rect where a point or size is needed if you wanted.


### The REPL

First and foremost is the `repl` module, which is great for exploring
and experimenting with Hydra's API. It's very similar to the terminal,
having readline-like functionality built-in.


### Where to begin

Since this is primarily a window manager, you'll probably want to look
at the `window` and `hotkey` modules first. Even using just these two
modules, you could make a very useful config.

But to make your config a little more full-featured, look into the
`menu`, `autolaunch`, `pathwatcher`, `updates`, and `notify`
modules. At the very least, the `menu` module is handy for knowing at
a glance whether Hydra is running or not.

When using the `window` module, you may find that you need a window's
application; look in the `application` module for what they can do.

Windows also belong to a screen, which is represented by the `screen`
module. You'll find Hydra's coordinate system detailed there.

The `settings` module is there for when you need to store and retrieve
Lua values between launches of Hydra (e.g. when you restart your
computer).

The `hydra` module has a few functions that don't really belong in any
other module. It's worth a peek.

The `timer` module is generally useful, for running one-off delayed
functions, or running a function regularly at an interval.

If you're into functional programming, check out the `fnutils` module
for things like map, reduce, filter, etc.

The `textgrid` module is perfect for almost any custom GUI task, such
as one-off dialog boxes, list choosers, displaying documentation,
having a readline-like REPL (see the `repl` module), window hints,
really almost anything. It's a bit low-level, but I suspect we'll
start seeing higher-level wrapper APIs for common tasks soon.

The `mouse` module is excellent for getting and setting the position
of the mouse; in an upcoming version, it will also have a callback
system for when the mouse has moved.

The `geometry` and `utf8` modules are just there for convenience. You
may never need them.

If you want to read a scrollback of your errors, the `logger` module
stores all printed information, and comes with a custom textgrid that
displays it conveniently for you.

You probably won't ever need to touch the `json`, but it's there in
case you need to. Hydra's internals use it for its documentation
system.

Check out the sample configs to see many of these modules in action.


### Third party modules

- The wiki is the definitive location for third party modules.
- Third party modules are encouraged to reside under `ext`.

END
group['items'] = []

File.write("docs/index.html", template.result(binding))
