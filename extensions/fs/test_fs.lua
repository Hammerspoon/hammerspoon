-- hs.fs tests
require("hs.fs")
require("hs.socket")

testDir = "/private/tmp/hs_fs_test_dir/"

function writeFile(filename, contents)
  io.open(filename, "w"):write(contents):close()
end

function setUp()
  os.execute("mkdir "..testDir)
  return success()
end

function tearDown()
  os.execute("rm -r "..testDir)
  return success()
end

function testMkdir()
  local dirname = testDir.."mkdir_test_directory"

  assertTrue(hs.fs.mkdir(dirname))
  local status, err = hs.fs.mkdir(dirname)
  assertFalse(status)
  assertIsEqual("File exists", err)

  return success()
end

function testChdir()
  local dirname = testDir.."chdir_test_directory"

  assertTrue(hs.fs.mkdir(dirname))
  assertTrue(hs.fs.chdir(dirname))
  assertIsEqual(dirname, hs.fs.currentDir())

  local status, err = hs.fs.chdir("some_non_existent_dir")
  assertIsNil(status)
  assertIsEqual("No such file or directory", err:match("No such file or directory"))

  return success()
end

function testRmdir()
  local dirname = testDir.."some_unique_directory/"
  local dirnameWithContents = testDir.."some_unique_directory_with_contents/"
  local filename = "test.txt"
  local result, errorMsg

  assertTrue(hs.fs.mkdir(dirname))
  assertTrue(hs.fs.rmdir(dirname))

  assertTrue(hs.fs.mkdir(dirnameWithContents))
  writeFile(dirnameWithContents..filename, "some text\n")
  result, errorMsg = hs.fs.rmdir(dirnameWithContents)
  assertIsNil(result)
  assertIsEqual(errorMsg, "Directory not empty")

  os.execute("rm "..dirnameWithContents..filename)
  assertTrue(hs.fs.rmdir(dirnameWithContents))

  result, errorMsg = hs.fs.rmdir("~/some_non_existent_dir")
  assertIsNil(result)
  assertIsEqual(errorMsg, "No such file or directory")

  return success()
end

function testAttributes()
  local dirname = testDir.."attributes_test_directory/"
  local filename = "test.txt"
  local pipename = "pipe"

  assertTrue(hs.fs.mkdir(dirname))
  writeFile(dirname..filename, "some text\n")
  os.execute("mkfifo "..dirname..pipename)

  local noFileInfo = hs.fs.attributes("~/non_existent_file")
  local dirMode = hs.fs.attributes(dirname, "mode")
  local fileInfo = hs.fs.attributes(dirname..filename)
  local fifoInfo = hs.fs.attributes(dirname..pipename)
  local charDeviceInfo = hs.fs.attributes("/dev/urandom")
  local blockDeviceInfo = hs.fs.attributes("/dev/disk0")

  assertIsNil(noFileInfo)
  assertIsEqual("directory", dirMode)
  assertIsEqual("file", fileInfo.mode)
  assertIsEqual("named pipe", fifoInfo.mode)
  assertIsEqual("char device", charDeviceInfo.mode)
  assertIsEqual("block device", blockDeviceInfo.mode)

  local status, err = hs.fs.attributes(dirname, "bad_attribute_name")
  assertIsNil(status)
  assertIsEqual("invalid attribute name 'bad_attribute_name'", err)

  if hs.socket then
    local sockname, socket = "sock", nil
    socket = hs.socket.server(dirname..sockname)
    assertIsEqual("socket", hs.fs.attributes(dirname..sockname).mode)
    socket:disconnect()
  end

  return success()
end

function testTags()
  local dirname = testDir.."tag_test_directory/"
  local filename = "test.txt"
  local filename2 = "test2.txt"
  local tags = {"really cool tag", "another cool tag"}
  local tag = {"some tag"}

  assertTrue(hs.fs.mkdir(dirname))
  writeFile(dirname..filename, "some text\n")
  writeFile(dirname..filename2, "some more text\n")

  hs.fs.chdir(dirname)

  assertFalse(pcall(hs.fs.tagsGet, "non_existent_file"))
  assertFalse(pcall(hs.fs.tagsSet, "non_existent_file", tags))

  assertIsNil(hs.fs.tagsGet(filename))
  assertIsNil(hs.fs.tagsGet(filename2))

  hs.fs.tagsAdd(filename, tags)
  hs.fs.tagsAdd(filename2, hs.fs.tagsGet(filename))
  assertListsEqual(tags, hs.fs.tagsGet(filename))
  assertListsEqual(tags, hs.fs.tagsGet(filename2))

  hs.fs.tagsAdd(filename, tag)
  assertListsEqual(table.pack(tag[1], table.unpack(tags)), hs.fs.tagsGet(filename))

  hs.fs.tagsRemove(filename, tag)
  assertListsEqual(tags, hs.fs.tagsGet(filename))

  hs.fs.tagsSet(filename, tag)
  assertListsEqual(tag, hs.fs.tagsGet(filename))

  hs.fs.tagsSet(filename, tags)
  assertListsEqual(tags, hs.fs.tagsGet(filename))

  hs.fs.tagsSet(filename2, {})
  assertIsNil(hs.fs.tagsGet(filename2))

  return success()
end

function testLinks()
  local dirname = testDir.."link_test_directory/"
  local filename = "test.txt"
  local symlinkname = "test.symlink"
  local hardlinkname = "test.hardlink"

  assertTrue(hs.fs.mkdir(dirname))
  writeFile(dirname..filename, "some text\n")

  assertTrue(hs.fs.link(dirname..filename, dirname..symlinkname, true))
  status, err = hs.fs.link(dirname..filename, dirname..symlinkname, true)
  assertIsNil(status)
  assertTrue(hs.fs.link(dirname..filename, dirname..hardlinkname))
  status, err2 = hs.fs.link(dirname..filename, dirname..hardlinkname)
  assertIsNil(status)

  assertIsEqual("file", hs.fs.attributes(dirname..symlinkname).mode)
  assertIsEqual("file", hs.fs.attributes(dirname..hardlinkname).mode)
  assertIsEqual("link", hs.fs.symlinkAttributes(dirname..symlinkname).mode)
  assertIsEqual("file", hs.fs.symlinkAttributes(dirname..hardlinkname).mode)

  return success()
end

function testTouch()
  local dirname = hs.fs.temporaryDirectory()
  local filename = "test.txt"
  local aTime, mTime = 300, 200

  local status, err = hs.fs.touch("non_existent_file")
  assertIsNil(status)
  assertIsEqual("No such file or directory", err)

  writeFile(dirname..filename, "some contents\n")
  assertTrue(hs.fs.touch(dirname..filename, aTime))
  assertIsEqual(aTime, hs.fs.attributes(dirname..filename).access)
  assertIsEqual(aTime, hs.fs.attributes(dirname..filename).modification)

  assertTrue(hs.fs.touch(dirname..filename, aTime, mTime))
  assertIsEqual(aTime, hs.fs.attributes(dirname..filename).access)
  assertIsEqual(mTime, hs.fs.attributes(dirname..filename).modification)

  return success()
end

function testFileUTI()
  local dirname = testDir.."file_uti_test_directory/"
  local filename = "test.txt"

  assertTrue(hs.fs.mkdir(dirname))
  writeFile(dirname..filename, "some text\n")

  assertIsEqual("public.plain-text", hs.fs.fileUTI(dirname..filename))
  assertIsNil(hs.fs.fileUTI("non_existent_file"))

  return success()
end

function testDirWalker()
  local dirname = testDir.."dirwalker_test_directory/"
  local filenames = {"test1.txt", "test2.txt", "test3.txt"}

  assertTrue(hs.fs.mkdir(dirname))
  hs.fnutils.each(filenames, function(filename)
      writeFile(dirname..filename, "some text\n")
    end)

  local iterfn, dirobj = hs.fs.dir(dirname)
  local dirContents = {}

  repeat
    local filename = dirobj:next()
    table.insert(dirContents, filename)
  until filename == nil
  dirobj:close()

  table.insert(filenames, "."); table.insert(filenames, "..")
  assertListsEqual(filenames, dirContents)

  iterfn, dirobj = hs.fs.dir(dirname)
  dirobj:close()

  local status, err = pcall(hs.fs.dir, "some_non_existent_dir")
  assertFalse(status)
  assertIsEqual("cannot open", err:match("cannot open"))

  return success()
end

function testLockDir()
  local dirname = testDir.."lockdir_test_directory/"
  local lock, lock2, err

  assertTrue(hs.fs.mkdir(dirname))

  lock, err = hs.fs.lockDir(dirname)
  assertIsUserdata(lock)
  assertIsNil(err)
  assertIsEqual("link", hs.fs.symlinkAttributes(dirname.."lockfile.lfs").mode)

  lock2, err = hs.fs.lockDir(dirname)
  assertIsEqual("File exists", err)

  lock:free()

  lock2, err = hs.fs.lockDir(dirname)
  assertIsUserdata(lock2)
  assertIsNil(err)
  assertIsEqual("link", hs.fs.symlinkAttributes(dirname.."lockfile.lfs").mode)

  lock2:free()

  return success()
end

function testLock()
  local dirname = testDir.."lock_test_directory/"
  local filename = "test.txt"
  local lock, err, lock2, err2

  assertTrue(hs.fs.mkdir(dirname))
  writeFile(dirname..filename, "1234567890")

  f = io.open(dirname..filename, "r")
  lock, err = hs.fs.lock(f, "r")
  assertTrue(lock)
  assertIsNil(err)
  lock2, err2 = hs.fs.lock(f, "w")
  assertIsNil(lock2)
  assertIsEqual("Bad file descriptor", err2)
  assertTrue(hs.fs.unlock(f))
  f:close()

  f = io.open(dirname..filename, "w")
  lock, err = hs.fs.lock(f, "w")
  assertTrue(lock)
  assertIsNil(err)
  lock2, err2 = hs.fs.lock(f, "r")
  assertIsNil(lock2)
  assertIsEqual("Bad file descriptor", err2)
  assertTrue(hs.fs.unlock(f))
  f:close()

  return success()
end

function testVolumesValues()
  print(path, newPath)
  if (type(path) == "string" and path == "/Volumes/"..ramdiskName and
      type(newPath) == "string" and newPath == "/Volumes/"..ramdiskRename) then
    return success()
  else
    return string.format("Waiting for success...")
  end
end

function testVolumes()
  local volumes = hs.fs.volume.allVolumes()
  assertIsEqual(false, volumes["/"].NSURLVolumeIsEjectableKey)

  ramdiskName = "ramDisk"
  ramdiskRename = "renamedDisk"

  local volumeWatcherCallback = function(event, info)
    if event == hs.fs.volume.didMount then
      path = info.path:match("(/Volumes/"..ramdiskName..")/?$")
      if not path then return end
      os.execute("diskutil rename "..ramdiskName.." "..ramdiskRename)
    end
    if event == hs.fs.volume.didRename then
      -- NOTE: in this case, `info` is returned as a NSURL object:
      newPath = info.path and info.path.filePath:match("(/Volumes/"..ramdiskRename..")/?$")
      if not newPath then return end
      hs.fs.volume.eject(newPath)
      volumeWatcher:stop()
    end
  end

  volumeWatcher = hs.fs.volume.new(volumeWatcherCallback):start()
  assertIsString(tostring(volumeWatcher))
  os.execute("diskutil erasevolume HFS+ '"..ramdiskName.."' `hdiutil attach -nomount ram://2048`")

  return success()
end
