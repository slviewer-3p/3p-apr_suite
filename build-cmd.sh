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
    
    mkdir -p "$DEBUG_OUT_DIR"
    mkdir -p "$RELEASE_OUT_DIR"
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
    mkdir -p "$INCLUDE_DIR"
    cp apr/include/*.h "$INCLUDE_DIR"
    cp apr-iconv/include/*.h "$INCLUDE_DIR"
    cp apr-util/include/*.h "$INCLUDE_DIR"
    mkdir "$INCLUDE_DIR/arch"
    cp apr/include/arch/apr_private_common.h "$INCLUDE_DIR/arch"
    cp -R "apr/include/arch/win32" "$INCLUDE_DIR/arch"
    mkdir "$INCLUDE_DIR/private"
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

	# do release builds
    pushd "$TOP_DIR/apr"
		LDFLAGS="-m32" CFLAGS="-m32 -O3" CXXFLAGS="-m32 -O3" ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib/release"
		make
		make install
    popd

	pushd "$TOP_DIR/apr-iconv"
		# NOTE: the autotools scripts in iconv don't honor the --libdir switch so we
		# need to build to a dummy prefix and copy the files into the correct place
		mkdir "$PREFIX/iconv"
		LDFLAGS="-m32" CFLAGS="-m32 -O3" CXXFLAGS="-m32 -O3" ./configure --prefix="$PREFIX/iconv" --with-apr="../apr"
		make
		make install

		# move the files into place
		mkdir -p "$PREFIX/bin"
		cp -a "$PREFIX"/iconv/lib/* "$PREFIX/lib/release"
		cp -r "$PREFIX/iconv/include/apr-1" "$PREFIX/include/"
		cp "$PREFIX/iconv/bin/apriconv" "$PREFIX/bin/"
		rm -rf "$PREFIX/iconv"
	popd

    pushd "$TOP_DIR/apr-util"
		# the autotools can't find the expat static lib with the layout of our
		# libraries so we need to copy the file to the correct location temporarily
		cp "$PREFIX/packages/lib/release/libexpat.a" "$PREFIX/packages/lib/"

		# the autotools for apr-util don't honor the --libdir switch so we
		# need to build to a dummy prefix and copy the files into the correct place
		mkdir "$PREFIX/util"
		LDFLAGS="-m32" CFLAGS="-m32 -O3" CXXFLAGS="-m32 -O3" ./configure --prefix="$PREFIX/util" --with-apr="../apr" --with-apr-iconv="../apr-iconv" --with-expat="$PREFIX/packages/"
		make
		make install

		# move files into place
		mkdir -p "$PREFIX/bin"
		cp -a "$PREFIX"/util/lib/* "$PREFIX/lib/release/"
		cp -r "$PREFIX/util/include/apr-1" "$PREFIX/include/"
		cp "$PREFIX"/util/bin/* "$PREFIX/bin/"
		rm -rf "$PREFIX/util"
		rm -rf "$PREFIX/packages/lib/libexpat.a"
    popd

    pushd "$TOP_DIR/apr"
		make distclean
    popd
	pushd "$TOP_DIR/apr-iconv"
		make distclean
    popd
    pushd "$TOP_DIR/apr-util"
		make distclean
    popd

	# do release builds
    pushd "$TOP_DIR/apr"
		LDFLAGS="-m32" CFLAGS="-m32 -O0 -gstabs+" CXXFLAGS="-m32 -O0 -gstabs+" ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib/debug"
		make
		make install
    popd

	pushd "$TOP_DIR/apr-iconv"
		# NOTE: the autotools scripts in iconv don't honor the --libdir switch so we
		# need to build to a dummy prefix and copy the files into the correct place
		mkdir "$PREFIX/iconv"
		LDFLAGS="-m32" CFLAGS="-m32 -O0 -gstabs+" CXXFLAGS="-m32 -O0 -gstabs+" ./configure --prefix="$PREFIX/iconv" --with-apr="../apr"
		make
		make install

		# move the files into place
		mkdir -p "$PREFIX/bin"
		cp -a "$PREFIX"/iconv/lib/* "$PREFIX/lib/debug"
		cp -r "$PREFIX/iconv/include/apr-1" "$PREFIX/include/"
		cp "$PREFIX/iconv/bin/apriconv" "$PREFIX/bin/"
		rm -rf "$PREFIX/iconv"
	popd

    pushd "$TOP_DIR/apr-util"
		# the autotools can't find the expat static lib with the layout of our
		# libraries so we need to copy the file to the correct location temporarily
		cp "$PREFIX/packages/lib/release/libexpat.a" "$PREFIX/packages/lib/"

		# the autotools for apr-util don't honor the --libdir switch so we
		# need to build to a dummy prefix and copy the files into the correct place
		mkdir "$PREFIX/util"
		LDFLAGS="-m32" CFLAGS="-m32 -O0 -gstabs+" CXXFLAGS="-m32 -O0 -gstabs+" ./configure --prefix="$PREFIX/util" --with-apr="../apr" --with-apr-iconv="../apr-iconv" --with-expat="$PREFIX/packages/"
		make
		make install

		# move files into place
		mkdir -p "$PREFIX/bin"
		cp -a "$PREFIX"/util/lib/* "$PREFIX/lib/debug/"
		cp -r "$PREFIX/util/include/apr-1" "$PREFIX/include/"
		cp "$PREFIX"/util/bin/* "$PREFIX/bin/"
		rm -rf "$PREFIX/util"
		rm -rf "$PREFIX/packages/lib/libexpat.a"
    popd

	# APR includes its own expat.h header that doesn't have all of the features
	# in the expat library that we have a dependency
	cp "$PREFIX/packages/include/expat/expat_external.h" "$PREFIX/include/apr-1/"
	cp "$PREFIX/packages/include/expat/expat.h" "$PREFIX/include/apr-1/"

	# clean 
    pushd "$TOP_DIR/apr"
		make distclean
    popd
	pushd "$TOP_DIR/apr-iconv"
		make distclean
    popd
    pushd "$TOP_DIR/apr-util"
		make distclean
    popd
;;
esac

mkdir -p "$STAGING_DIR/LICENSES"
cat "$TOP_DIR/apr/LICENSE" > "$STAGING_DIR/LICENSES/apr_suite.txt"

pass

