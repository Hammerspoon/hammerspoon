#!/bin/sh
set -eux

export HS_RESOURCES="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
export HS_DST="${HS_RESOURCES}/extensions/hs"
export HS_MODULES="alert \
    application \
    audiodevice \
    base64 \
    battery \
    brightness \
    caffeinate \
    chooser \
    console \
    crash \
    dockicon \
    drawing \
    eventtap \
    fs \
    hash \
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
    menubar \
    milight \
    mouse \
    notify \
    osascript \
    pasteboard \
    pathwatcher \
    screen \
    settings \
    socket \
    sound \
    speech \
    styledtext \
    task \
    timer \
    uielement \
    urlevent \
    usb \
    webview \
    wifi \
    window"
export HS_WATCHERS="application \
    audiodevice \
    battery \
    caffeinate \
    screen \
    spaces \
    usb \
    wifi"
export HS_LUAONLY="_coresetup \
    appfinder \
    applescript \
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
    spaces \
    tabs \
    utf8 \
    doc"

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

# Special copier for hs.eventtap.event
cp -av "${BUILT_PRODUCTS_DIR}/libeventtapevent.dylib" "${HS_DST}/eventtap/event.so"

# Special copier for hs.drawing.color
mkdir -pv "${HS_DST}/drawing/color"
cp -av "${SRCROOT}/extensions/drawing/color/init.lua" "${HS_DST}/drawing/color/init.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libdrawing_color.dylib" "${HS_DST}/drawing/color/internal.so"

# Special copier for hs.ipc
mkdir -pv "${HS_DST}/ipc/bin"
mkdir -pv "${HS_DST}/ipc/share/man/man1"
cp -av "${SRCROOT}/extensions/ipc/cli/hs.man" "${HS_DST}/ipc/share/man/man1/hs.1"
cp -av "${BUILT_PRODUCTS_DIR}/hs" "${HS_DST}/ipc/bin/hs"

# Special copier for hs.speech.listener
cp -av "${BUILT_PRODUCTS_DIR}/libspeechlistener.dylib" "${HS_DST}/speech/listener.so"

# Special copier for hs.network submodules
cp -av "${SRCROOT}/extensions/network/configuration.lua" "${HS_DST}/network/configuration.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkconfiguration.dylib" "${HS_DST}/network/configurationinternal.so"
cp -av "${SRCROOT}/extensions/network/host.lua" "${HS_DST}/network/host.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkhost.dylib" "${HS_DST}/network/hostinternal.so"
cp -av "${SRCROOT}/extensions/network/reachability.lua" "${HS_DST}/network/reachability.lua"
cp -av "${BUILT_PRODUCTS_DIR}/libnetworkreachability.dylib" "${HS_DST}/network/reachabilityinternal.so"

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

# Special copier for hs.fs submodule
cp -av "${BUILT_PRODUCTS_DIR}/libfsvolume.dylib" "${HS_DST}/fs/volume.so"

# Special (compiling) copier for hs.chooser
ibtool --compile "${HS_RESOURCES}/HSChooserWindow.nib" "${SRCROOT}/extensions/chooser/HSChooserWindow.xib"
