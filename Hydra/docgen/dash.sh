TARGETDIR="$1"
if [ -z "$TARGETDIR" ]; then
	echo 'no target dir (like ../../../Dash-User-Contributions/docsets/Hydra/ ), limping on'
fi

rm -rf Hydra.docset
mkdir -p Hydra.docset/Contents/Resources/Documents/
cat > Hydra.docset/Contents/Info.plist << __EOF__
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>hydra</string>
	<key>CFBundleName</key>
	<string>Hydra</string>
	<key>DocSetPlatformFamily</key>
	<string>hydra</string>
	<key>isDashDocset</key>
	<true/>
	<key>dashIndexFilePath</key>
	<string>index.html</string>
</dict>
</plist>
__EOF__

ruby ./gendocs.rb --dash | sqlite3 Hydra.docset/Contents/Resources/docSet.dsidx
cp -r docs/ Hydra.docset/Contents/Resources/Documents/
cp *.css Hydra.docset/Contents/Resources/Documents/

cat >> Hydra.docset/Contents/Resources/Documents/styles.css << __EOF__
	#modules { width: 0px; }
#module { margin-left: 0px;
__EOF__

cp ../XcodeCrap/Images.xcassets/AppIcon.appiconset/icon_32x32.png Hydra.docset/icon.png

tar --exclude='.DS_Store' -czf Hydra.tgz Hydra.docset

if [ -n "$TARGETDIR" ]; then
  cp Hydra.tgz "$TARGETDIR"/
  cp ../XcodeCrap/Images.xcassets/AppIcon.appiconset/icon_16x16.png "$TARGETDIR"/icon.png
  cp ../XcodeCrap/Images.xcassets/AppIcon.appiconset/icon_16x16@2x.png "$TARGETDIR"/icon@2x.png
fi
