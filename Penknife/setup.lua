os.exit = core.exit

-- think about this better
package.path = os.getenv("HOME") .. "/.hydra/?.lua" .. ';' .. package.path

-- put this in ObjC maybe?
-- hydra.call(hydra.reload)
