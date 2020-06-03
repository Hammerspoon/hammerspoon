#!/bin/sh
set -eux

export HS_RESOURCES="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
export HS_DST="${HS_RESOURCES}/extensions/hs"
export HS_MODULES="application \
    audiodevice \
    audiounit \
    base64 \
    battery \
    bonjour \
    brightness \
    caffeinate \
    canvas \
    chooser \
    console \
    crash \
    dialog \
    distributednotifications \
    doc \
    dockicon \
    eventtap \
    fs \
    hash \
    hid \
    hints \
    host \
    hotkey \
    http \
    httpserver \
    image \
    ipc \
    json \
    keycodes \
    location \
    math \
    menubar \
    midi \
    milight \
    mouse \
    noises \
    notify \
    osascript \
    pasteboard \
    pathwatcher \
    plist \
    screen \
    settings \
    sharing \
    socket \
    sound \
    speech \
    spotlight \
    streamdeck \
    styledtext \
    task \
    timer \
    uielement \
    urlevent \
    usb \
    websocket \
    webview \
    wifi \
    window"
export HS_WATCHERS="application \
    audiodevice \
    battery \
    caffeinate \
    pasteboard \
    screen \
    spaces \
    uielement \
    usb \
    wifi"
export HS_LUAONLY="_coresetup \
    alert \
    appfinder \
    applescript \
    deezer \
    drawing \
    expose \
    fnutils \
    geometry \
    grid \
    inspect \
    itunes \
    javascript \
    layout \
    logger \
    messages \
    mjomatic \
    network \
    redshift \
    spotify \
    spoons \
    spaces \
    tabs \
    tangent \
    utf8 \
    vox \
    watchable"

# First, copy all of our init.lua's into the destination bundle
for hs_lua in ${HS_LUAONLY} ${HS_MODULES} ; do
  mkdir -pv "${HS_DST}/${hs_lua}"
  cp -av "${SRCROOT}/extensions/${hs_lua}/init.lua" "${HS_DST}/${hs_lua}/init.lua"
done

# Now, copy all of our internal.so's
for hs_module in ${HS_MODULES} ; do
  mkdir -pv "${HS_DST}/${hs_module}"
  cp -av "${BUILT_PRODUCTS_DIR}/lib${hs_module}.dylib" "${HS_DST}/${hs_module}/internal.so"
done

# Now, copy our watcher.so's
for hs_watcher in ${HS_WATCHERS} ; do
  mkdir -pv "${HS_DST}/${hs_watcher}"
  cp -av "${BUILT_PRODUCTS_DIR}/lib${hs_watcher}watcher.dylib" "${HS_DST}/${hs_watcher}/watcher.so"
done

# Special copier for hs.doc
cp -av "${SRCROOT}/extensions/doc/lua.json" "${HS_DST}/doc/lua.json"
cp -av "${BUILT_PRODUCTS_DIR}/libdoc.dylib" "${HS_DST}/doc/markdown.so"
cp -av "${SRCROOT}/extensions/doc/builder.lua" "${HS_DST}/doc"
cp -av "${SRCROOT}/extensions/doc/hsdocs" "${HS_DST}/doc"
cp -av "${SRCROOT}/scripts/docs/templates/docs.css" "${HS_DST}/doc/hsdocs"

# Special copier for hs.eventtap.event
cp -av "${BUILT_PRODUCTS_DIR}/libeventtapevent.dylib" "${HS_DST}/eventtap/event.so"

# Special copier for hs.drawing.color
mkdir -pv "${HS_DST}/drawing/color"
cp -av "${SRCROOT}/extensions/drawing/color/init.lua" "${HS_DST}/drawing/color/init.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libdrawing_color.dylib" "${HS_DST}/drawing/color/internal.so"

# Special copier for hs.drawing.canvasWrapper
cp -av "${SRCROOT}/extensions/drawing/canvasWrapper.lua" "${HS_DST}/drawing/canvasWrapper.lua"

# Special copier for hs.canvas.matrix
cp -av "${SRCROOT}/extensions/canvas/matrix.lua" "${HS_DST}/canvas/matrix.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libcanvasmatrix.dylib" "${HS_DST}/canvas/matrix_internal.so"

# Special copier for hs.ipc
mkdir -pv "${HS_DST}/ipc/bin"
mkdir -pv "${HS_DST}/ipc/share/man/man1"
cp -av "${SRCROOT}/extensions/ipc/cli/cmdpost.man" "${HS_DST}/ipc/share/man/man1/cmdpost.1"
cp -av "${BUILT_PRODUCTS_DIR}/cmdpost" "${HS_DST}/ipc/bin/cmdpost"
cp -av "${BUILT_PRODUCTS_DIR}/cmdpost.dSYM" "${HS_DST}/ipc/bin/cmdpost.dSYM"

# Special copier for hs.host.locale
mkdir -pv "${HS_DST}/host/locale"
cp -av "${SRCROOT}/extensions/host/locale/init.lua" "${HS_DST}/host/locale/init.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libhost_locale.dylib" "${HS_DST}/host/locale/internal.so"

# Special copier for hs.httpserver.hsminweb support
cp -av "${SRCROOT}/extensions/httpserver/hsminweb.lua" "${HS_DST}/httpserver/hsminweb.lua"
cp -av "${SRCROOT}/extensions/httpserver/timeout3" "${HS_DST}/httpserver/timeout3"
cp -av "${SRCROOT}/extensions/httpserver/cgilua_compatibility_functions.lua" "${HS_DST}/httpserver/cgilua_compatibility_functions.lua"

# Special copier for hs.speech.listener
cp -av "${BUILT_PRODUCTS_DIR}/libspeechlistener.dylib" "${HS_DST}/speech/listener.so"

# Special copier for hs.location.geocoder submodule
cp -av "${SRCROOT}/extensions/location/geocoder.lua" "${HS_DST}/location/geocoder.lua"

# Special copier for hs.network submodules
cp -av "${SRCROOT}/extensions/network/configuration.lua" "${HS_DST}/network/configuration.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkconfiguration.dylib" "${HS_DST}/network/configurationinternal.so"
cp -av "${SRCROOT}/extensions/network/host.lua" "${HS_DST}/network/host.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkhost.dylib" "${HS_DST}/network/hostinternal.so"
cp -av "${SRCROOT}/extensions/network/reachability.lua" "${HS_DST}/network/reachability.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkreachability.dylib" "${HS_DST}/network/reachabilityinternal.so"
mkdir -pv "${HS_DST}/network/ping"
cp -av "${SRCROOT}/extensions/network/ping/init.lua" "${HS_DST}/network/ping/init.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkping.dylib" "${HS_DST}/network/ping/internal.so"

# Special copier for hs.socket.udp
cp -av "${BUILT_PRODUCTS_DIR}/libsocketudp.dylib" "${HS_DST}/socket/udp.so"

# Special copier for hs.window submodules
cp -av "${SRCROOT}/extensions/window/filter.lua" "${HS_DST}/window/filter.lua"
cp -av "${SRCROOT}/extensions/window/tiling.lua" "${HS_DST}/window/tiling.lua"
cp -av "${SRCROOT}/extensions/window/layout.lua" "${HS_DST}/window/layout.lua"
cp -av "${SRCROOT}/extensions/window/switcher.lua" "${HS_DST}/window/switcher.lua"
cp -av "${SRCROOT}/extensions/window/highlight.lua" "${HS_DST}/window/highlight.lua"

# Special copier for hs.webview.usercontent submodule
cp -av "${BUILT_PRODUCTS_DIR}/libwebviewusercontent.dylib" "${HS_DST}/webview/usercontent.so"

# Special copier for hs.webview.toolbar submodule
cp -av "${SRCROOT}/extensions/webview/toolbar.lua" "${HS_DST}/webview/toolbar.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libwebviewtoolbar.dylib" "${HS_DST}/webview/toolbar_internal.so"

# Special copier for hs.webview.datastore submodule
cp -av "${BUILT_PRODUCTS_DIR}/libwebviewdatastore.dylib" "${HS_DST}/webview/datastore.so"

# Special copier for hs.bonjour.service submodule
cp -av "${BUILT_PRODUCTS_DIR}/libbonjourservice.dylib" "${HS_DST}/bonjour/service.so"

# Special copier for hs.fs submodule
cp -av "${BUILT_PRODUCTS_DIR}/libfsvolume.dylib" "${HS_DST}/fs/volume.so"
cp -av "${BUILT_PRODUCTS_DIR}/libfsxattr.dylib" "${HS_DST}/fs/xattr.so"

# Special (compiling) copier for hs.chooser
ibtool --compile "${HS_RESOURCES}/HSChooserWindow.nib" "${SRCROOT}/extensions/chooser/HSChooserWindow.xib"

# Special copier for hs.sqlite3
mkdir -pv "${HS_DST}/sqlite3"
cp -av "${SRCROOT}/extensions/sqlite3/init.lua" "${HS_DST}/sqlite3/init.lua"
cp -av "${BUILT_PRODUCTS_DIR}/liblsqlite3.dylib" "${HS_DST}/sqlite3/lsqlite3.so"

# Special copier for hs.spoons templates directory
cp -av "${SRCROOT}/extensions/spoons/templates" "${HS_DST}/spoons"
