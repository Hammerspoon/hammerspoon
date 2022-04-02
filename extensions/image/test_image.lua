function testGetExifFromPath()
  
  assertIsNil(hs.image.getExifFromPath(""))
  assertIsNil(hs.image.getExifFromPath("asdfasdfasddsa"))
  assertIsNil(hs.image.getExifFromPath("/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.sdef"))
  assertIsTable(hs.image.getExifFromPath("/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns"))

  return success()
end
