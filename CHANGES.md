### Changes from Mjolnir 0.2

- Did anyone actually install 0.2 while it was available for those 5 minutes?

### Changes from Mjolnir 0.1

- The UI has changed drastically. Expect nothing to be in the same
  place or look the same. Pretend it's a brand new app.
- Extensions are now handled by LuaRocks instead of by the app itself.
- The "core" namespace has been renamed to "mj".
- The 'mj.window' module now ships with the 'mj.application' LuaRocks
  package since they depend on each other.
- `mj.screen:frame_without_dock_or_menu()` is now called `mj.screen:frame()`
- `mj.screen:frame_including_dock_and_menu()` is now called `mj.screen:fullframe()`
