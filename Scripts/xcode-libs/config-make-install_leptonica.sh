#!/bin/zsh

name=$1
os_arch=$2
dirname=$3

thisAbsPath=${0:A}
parentPath=${thisAbsPath%/*}

setEnvPath=$parentPath/../set_env.sh
source $setEnvPath || { echo "ERROR could not source $setEnvPath"; exit 1 }


print -n "$os_arch: "

# Use to verify a previous build and skip, or verify this build
thisLib=$ROOT/$os_arch/lib/liblept.a

# Skip build if check returns w/0
checkForXcodeLib $thisLib $ARCH && exit 0

verifyPlatform || exit 1

cflags=(
  "-isysroot /Applications/Xcode.app/Contents/Developer/Platforms/$PLATFORM"
  $PLATFORM_MIN_VERSION
  "--target=$TARGET"
  
  "-I$ROOT/$os_arch/include"

  '-fembed-bitcode'
  '-no-cpp-precomp'
  '-O2'
  '-pipe'
)

config_flags=(
  CC="$(xcode-select -p)/usr/bin/gcc"
  CXX="$(xcode-select -p)/usr/bin/g++"
  CXX_FOR_BUILD="$(xcode-select -p)/usr/bin/g++"
  CFLAGS="$cflags"
  CPPFLAGS="$cflags"
  CXXFLAGS="$cflags -Wno-deprecated-register"
  LDFLAGS="-L$ROOT/$os_arch/lib -L/Applications/Xcode.app/Contents/Developer/Platforms/$PLATFORM/usr/lib/"
  LIBS='-lz -lpng -ljpeg -ltiff'
  PKG_CONFIG_PATH="$ROOT/$os_arch/lib/pkgconfig"

  '--enable-shared=no'
  "--host=$TARGET"
  "--prefix=$ROOT/$os_arch"

  '--disable-programs'
  '--with-jpeg'
  '--with-libpng'
  '--with-libtiff'
  '--with-zlib'
  '--without-giflib'
  '--without-libwebp'
)

xc mkdir -p $SOURCES/$dirname/$os_arch || exit 1
xc cd $SOURCES/$dirname/$os_arch  || exit 1

# "Step 2" is pre-configure, in build script
print -n 'configuring... '
xl $name "3_config_$os_arch" ../configure $config_flags || exit 1
print -n 'done, '

print -n 'making... '
xl $name "4_clean_$os_arch" make clean || exit 1
xl $name "4_make_$os_arch" make -j || exit 1
print -n 'done, '

print -n 'installing... '
xl $name "5_install_$os_arch" make install || exit 1
print 'done.'

validateBuiltLib $thisLib $ARCH || exit 1