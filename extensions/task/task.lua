--- === hs.task ===
---
--- Execute processes in the background and capture their output
---
--- Notes:
---  * This is not intended to be used for processes which never exit. While it is possible to run such things with hs.task, it is not possible to read their output while they run and if they produce significant output, eventually the internal OS buffers will fill up and the task will be suspended.
---  * An hs.task object can only be used once

local task = require "hs.libtask"

return task
