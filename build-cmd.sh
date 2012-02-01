#!/bin/bash

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

STAGING_DIR="$(pwd)"
TOP_DIR="$(dirname "$0")"

case "$AUTOBUILD_PLATFORM" in
"windows")
    pushd "$TOP_DIR"
    DEBUG_OUT_DIR="$STAGING_DIR/lib/debug"
    RELEASE_OUT_DIR="$STAGING_DIR/lib/release"

    load_vsvars
 
    build_sln "apr-util/aprutil.sln" "Debug|Win32"   "apr"  || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32" "apr"  || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"   "aprutil"  || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32" "aprutil"  || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"   "apriconv"  || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32" "apriconv"  || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"   "xml"  || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32" "xml"  || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"    "libapr" || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32"  "libapr" || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"    "libapriconv" || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32"  "libapriconv" || exit 1
    build_sln "apr-util/aprutil.sln" "Debug|Win32"    "libaprutil" || exit 1
    build_sln "apr-util/aprutil.sln" "Release|Win32"  "libaprutil" || exit 1
    
    mkdir -p "$DEBUG_OUT_DIR"   || echo "$DEBUG_OUT_DIR exists"
    mkdir -p "$RELEASE_OUT_DIR" || echo "$RELEASE_OUT_DIR exists"
    cp "apr/LibD/apr-1.lib" "$DEBUG_OUT_DIR" || exit 1
    cp "apr/LibR/apr-1.lib" "$RELEASE_OUT_DIR" || exit 1
    cp "apr-util/LibD/aprutil-1.lib" "$DEBUG_OUT_DIR" || exit 1
    cp "apr-util/LibR/aprutil-1.lib" "$RELEASE_OUT_DIR" || exit 1
    cp "apr-iconv/LibD/apriconv-1.lib" "$DEBUG_OUT_DIR" || exit 1
    cp "apr-iconv/LibR/apriconv-1.lib" "$RELEASE_OUT_DIR" || exit 1
    cp "apr/Debug/libapr-1."{lib,dll} "$DEBUG_OUT_DIR" || exit 1
    cp "apr/Release/libapr-1."{lib,dll} "$RELEASE_OUT_DIR" || exit 1
    cp "apr/Debug/libapr_src.pdb" "$DEBUG_OUT_DIR" || exit 1
    cp "apr/Release/libapr_src.pdb" "$RELEASE_OUT_DIR" || exit 1
    cp "apr-iconv/Debug/libapriconv-1."{lib,dll} "$DEBUG_OUT_DIR" || exit 1
    cp "apr-iconv/Release/libapriconv-1."{lib,dll} "$RELEASE_OUT_DIR" || exit 1
    cp "apr-util/Debug/libaprutil-1."{lib,dll} "$DEBUG_OUT_DIR" || exit 1
    cp "apr-util/Release/libaprutil-1."{lib,dll} "$RELEASE_OUT_DIR" || exit 1
    cp "apr-util/Debug/libaprutil_src.pdb" "$DEBUG_OUT_DIR" || exit 1
    cp "apr-util/Release/libaprutil_src.pdb" "$RELEASE_OUT_DIR" || exit 1

    INCLUDE_DIR="$STAGING_DIR/include/apr-1"
    mkdir -p "$INCLUDE_DIR"      || echo "$INCLUDE_DIR exists"
    cp apr/include/*.h "$INCLUDE_DIR"
    cp apr-iconv/include/*.h "$INCLUDE_DIR"
    cp apr-util/include/*.h "$INCLUDE_DIR"
    mkdir "$INCLUDE_DIR/arch"    || echo "$INCLUDE_DIR/arch exists"
    cp apr/include/arch/apr_private_common.h "$INCLUDE_DIR/arch"
    cp -R "apr/include/arch/win32" "$INCLUDE_DIR/arch"
    mkdir "$INCLUDE_DIR/private" || echo "$INCLUDE_DIR/private exists"
    cp -R apr-util/include/private "$INCLUDE_DIR"
    popd
;;
'darwin')
    PREFIX="$STAGING_DIR"
    
    opts='-arch i386 -iwithsysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5'

    pushd "$TOP_DIR/apr"
    CC="gcc-4.2" CFLAGS="$opts" CXXFLAGS="$opts" LDFLAGS="$opts" \
        ./configure --prefix="$PREFIX"
    make
    make install
    popd
    
    pushd "$TOP_DIR/apr-util"
    CC="gcc-4.2" CFLAGS="$opts" CXXFLAGS="$opts" LDFLAGS="$opts" \
        ./configure --prefix="$PREFIX" --with-apr="$PREFIX" \
        --with-expat="$PREFIX"
    make
    make install
    popd
    
    mv "$PREFIX/lib" "$PREFIX/release"
    mkdir -p "$PREFIX/lib"
    mv "$PREFIX/release" "$PREFIX/lib/release"
    
    pushd "$PREFIX/lib/release"
    for lib in `find . -name "*.dylib"`
    do
        fix_dylib_id $lib
        
        # Somehow a strange dependency is introduced into libs dependant on the apr lib.  Fix it.
        strange_apr="$(otool -L "$lib" | grep 'libapr-1' | awk '{ print $1 }')"
		install_name_tool -change "$strange_apr" "@loader_path/$(readlink "libapr-1.dylib")" "$lib"
    done
    popd
;;
'linux')
    PREFIX="$STAGING_DIR"

    pushd "$TOP_DIR/apr"
    LDFLAGS="-m32" CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$PREFIX"
    make
    make install
    popd

    pushd "$TOP_DIR/apr-util"
    LDFLAGS="-m32" CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$PREFIX" --with-apr="$PREFIX" \
        --with-expat=builtin
    make
    make install
    popd

    mv "$PREFIX/lib" "$PREFIX/release"
    mkdir -p "$PREFIX/lib"
    mv "$PREFIX/release" "$PREFIX/lib"
;;
esac

mkdir -p "$STAGING_DIR/LICENSES"
cat "$TOP_DIR/apr/LICENSE" > "$STAGING_DIR/LICENSES/apr_suite.txt"

pass

