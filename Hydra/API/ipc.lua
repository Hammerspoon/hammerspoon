--- ipc
---
--- Interface with Hydra from the command line.

local function rawhandler(str)
  local fn, err = load(str)
  if fn then return fn() else return err end
end

--- ipc.handler(str) -> value
--- The default handler for IPC, called by hydra-cli. Default implementation evals the string and returns the result.
--- You may override this function if for some reason you want to implement special evaluation rules for executing remote commands.
--- The return value of this function is always turned into a string via tostring() and returned to hydra-cli.
--- If an error occurs, the error message is returned instead.
ipc.handler = rawhandler

function ipc._handler(raw, str)
  local fn = ipc.handler
  if raw then fn = rawhandler end
  local ok, val = hydra.call(function() return fn(str) end)
  return tostring(val)
end

local function envstuff(prefix, dryrun)
  prefix = prefix or "/usr/local"

  local fn = os.execute
  if dryrun then fn = print end

  local hydradestdir = string.format("'%s/bin'", prefix)
  local manpagedestdir = string.format("'%s/share/man/man1'", prefix)

  return fn, hydradestdir, manpagedestdir
end

--- ipc.link(prefix = "/usr/local", dryrun = nil)
--- Symlinks ${prefix}/bin/hydra and ${prefix}/share/man/man1/hydra.1
--- If dryrun is true, prints the commands it would run.
function ipc.link(prefix, dryrun)
  local fn, hydradestdir, manpagedestdir = envstuff(prefix, dryrun)

  fn(string.format("mkdir -p %s", hydradestdir))
  fn(string.format("mkdir -p %s", manpagedestdir))

  fn(string.format('ln -s "%s"/hydra %s/hydra', hydra.resourcesdir, hydradestdir))
  fn(string.format('ln -s "%s"/hydra.1 %s/hydra.1', hydra.resourcesdir, manpagedestdir))

  print("Done. Now you can do these things:")
  print([[$ hydra 'hydra.alert("hello world")']])
  print([[$ man hydra]])
end

--- ipc.unlink(prefix = "/usr/local", dryrun = false)
--- Removes ${prefix}/bin/hydra and ${prefix}/share/man/man1/hydra.1
--- If dryrun is true, prints the commands it would run.
function ipc.unlink(prefix, dryrun)
  local fn, hydradestdir, manpagedestdir = envstuff(prefix, dryrun)

  fn(string.format('rm -f %s/hydra', hydradestdir))
  fn(string.format('rm -f %s/hydra.1', manpagedestdir))

  print("Done.")
end
