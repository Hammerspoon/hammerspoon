#!/bin/bash

#  build_extensions.sh
#  Hammerspoon
#
#  Created by Peter van Dijk on 12/10/14.

set -e -u -x

LASTMAKEFILE=""
ISXCODE=""

function cleanup() {
    if [ "${LASTMAKEFILE}" != "" ]; then
        rm "${SRCROOT}/extensions/${LASTMAKEFILE}"
    fi
}
trap cleanup EXIT

if [ -z "${SRCROOT-}" ]; then
    echo "Building in standalone mode."
    SRCROOT="$(dirname "$0")"
    if [ "${SRCROOT}" == "." ]; then
        SRCROOT="$(pwd)"
    fi
    SRCROOT="${SRCROOT}/.."
    T="${SRCROOT}/extensions/.build"
else
    echo "Building in Xcode mode."
    ISXCODE="1"
    T="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/extensions/hs"
fi

# srcdir is ., makes things easy
cd "${SRCROOT}/extensions"

# stick target-dir in T, keeps things short
if [ -e "${T}" ]; then
    rm -rf "${T}"
fi
mkdir -p "${T}"

for dir in $(find . -type d -mindepth 1 -maxdepth 1 ! -name '.build') ; do
    MIGRATED=0
    dir=$(basename "$dir")

    # Check if this module has been migrated to Xcode building
    case "${dir}" in
        "alert"|"appfinder"|"applescript"|"application"|"audiodevice"|"base64"|"battery"|"brightness"|"caffeinate"|"crash"|"dockicon"|"drawing"|"fnutils"|"fs"|"geometry"|"grid"|"hash"|"hints")
            MIGRATED=1
            ;;
        "host"|"hotkey"|"http"|"image"|"inspect"|"itunes"|"json"|"layout"|"location")
            MIGRATED=1
            ;;
    esac

    if [ "${MIGRATED}" == "0" ]; then
        # Reset variables that may have been set by a previous iteration's build_vars.sh
        unset EXTRA_CFLAGS DEBUG_CFLAGS EXTRA_LDFLAGS

        # Check if this module has a Makefile already
        if [ ! -e "${dir}/Makefile" ]; then
            cp build_extensions.Makefile "${dir}/Makefile"
            LASTMAKEFILE="${dir}/Makefile"
        fi

        # Check if this module is Lua-only
        if [ -e "${dir}/internal.m" ]; then
            LUAONLY=0
        else
            LUAONLY=1
        fi

        # Set environment variables
        export PREFIX="${T}"
        if [ "${CONFIGURATION:-''}" != "Debug" ]; then
            export DEBUG_CFLAGS=""
        fi

        # Import any environment variables the module wants to set
        if [ -e "${dir}/build_vars.sh" ]; then
            . "${dir}/build_vars.sh"
        fi

        # Do the build
        pushd "${dir}"

        if [ "${LUAONLY}" == "1" ]; then
            make install-lua
        else
            make install
            if [ -n "${ISXCODE}" ]; then
                for dsymfile in *.dSYM ; do
                    DSYM_DEST="${BUILT_PRODUCTS_DIR}/${dir}-${dsymfile}"
                    if [ -d "${DSYM_DEST}" ]; then
                        rm -rf "${DSYM_DEST}"
                    fi
                    cp -a "$dsymfile" "${DSYM_DEST}"
                done
            fi
            make clean
        fi

        popd

        if [ "${LASTMAKEFILE}" != "" ]; then
            rm "${LASTMAKEFILE}"
            LASTMAKEFILE=""
        fi
    fi
done

echo "Done. You will find your modules in ${T}/"
