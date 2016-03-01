-- hs.fs tests

homeDir = os.getenv("HOME").."/"

function makeHomedirFile(filename, contents)
  io.open(homeDir..filename, "w"):write(contents):close()
end

function makeHomedirDir(dirname)
  os.execute("mkdir "..homeDir..dirname)
end

function makeLink(filename, linkname)

end

function testRmdir()
  local dirname = "some_unique_directory"
  local dirnameWithContents = "some_unique_directory_with_contents"
  local filename = "test.txt"
  local result, errorMsg

  makeHomedirDir(dirname)
  assertTrue(hs.fs.rmdir("~/"..dirname))

  makeHomedirDir(dirnameWithContents)
  makeHomedirFile(dirnameWithContents.."/"..filename, "some text\n")
  result, errorMsg = hs.fs.rmdir("~/"..dirnameWithContents)
  assertIsNil(result)
  assertIsEqual(errorMsg, "Directory not empty")

  os.execute("rm "..homeDir..dirnameWithContents.."/"..filename)
  assertTrue(hs.fs.rmdir("~/"..dirnameWithContents))

  result, errorMsg = hs.fs.rmdir("~/some_non_existent_dir")
  assertIsNil(result)
  assertIsEqual(errorMsg, "No such file or directory")

  return success()
end

function testChdir()
  local dirname = "some_directory"

  makeHomedirDir(dirname)
  assertTrue(hs.fs.chdir("~/"..dirname))
  assertIsEqual(homeDir..dirname, hs.fs.currentDir())

  return success()
end

function testAttributes()
  local dirname = "some_test_directory"
  local filename = "test.txt"

  makeHomedirDir(dirname)
  makeHomedirFile(dirname.."/"..filename, "some text\n")

  local noFileInfo = hs.fs.attributes("~/non_existent_file")
  local dirInfo = hs.fs.attributes("~/"..dirname)
  local fileInfo = hs.fs.attributes("~/"..dirname.."/"..filename)

  assertIsNil(noFileInfo)
  assertIsEqual("directory", dirInfo.mode)
  assertIsEqual("file", fileInfo.mode)

  os.execute("rm -r "..homeDir..dirname)

  return success()

end

