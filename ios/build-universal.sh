#! /bin/bash

sdkver=4.3
sdkinstdir=/Developer
srcdir=../../libjpeg-turbo

ARCHS="armv6 armv7 i686"

function error() {
    echo "$@"
    exit 1
}

trap "error \"Exiting: interrupt\"" SIGINT SIGTERM
trap "error \"Exiting: error\"" ERR

function absdir() {
    local curdir=$(pwd)
    cd "$1"
    echo $(pwd)
    cd "$curdir"
}

function clean() {
    for i in $ARCHS; do
        echo rm -rf "build-$i"
        rm -rf "build-$i"
    done
    echo rm -f lib include
    rm -rf lib include
}

function configure() {
    local simd=1
    local simdflags
    local cflags
    local platformdir
    local sysroot
    local host
    local gcc

    local platform=iPhoneOS # iPhoneOS or iPhoneSimulator
    local arch=arm
    local subarch="$1"
    local cflags="-miphoneos-version-min=4.0"
    case "$subarch" in
        armv6)
            cflags="$cflags -mfloat-abi=softfp"
            cflags="$cflags -march=armv6 -mcpu=arm1176jzf-s -mfpu=vfp"
            ;;
        armv7)
            cflags="$cflags -mfloat-abi=softfp"
            cflags="$cflags -march=armv7 -mcpu=cortex-a8 -mtune=cortex-a8 -mfpu=neon"
            ;;
        i686)
            arch=i686
            platform=iPhoneSimulator
            ;;
        *)
            error "Unsupported platform $subarch"
            ;;
    esac

    platformdir="$sdkinstdir/Platforms/$platform.platform"
    sysroot="$platformdir/Developer/SDKs/$platform$sdkver.sdk"
    host="$arch-apple-$os"
    gcc="$platformdir/Developer/usr/bin/$host-gcc-$gccver"

    CC="$gcc" \
    LD="$gcc" \
    CFLAGS="-isysroot $sysroot \
        --sysroot=$sysroot \
        $cflags" \
    LDFLAGS="-isysroot $sysroot \
        --sysroot=$sysroot \
        $cflags" \
    $srcdir/configure --host $host \
        --prefix=$(pwd)/INSTALL \
        --disable-shared --enable-static \
        $simdflags
}

function build() {
    local curdir=$(pwd)
    for i in $ARCHS; do
        echo "Building for $i..."
        cd "$curdir"
        mkdir -p build-"$i" || error "failed to make build directory for $i"
        cd build-"$i" || error "failed to change to build directory for $i"
        configure "$i" && make install || error "failed to build $i"
        cd "$curdir"
    done
}

function install() {
    echo "Copying headers..."
    mkdir -p include
    cp build-armv7/INSTALL/include/* include

    echo "Running lipo..."
    mkdir -p lib
    for i in libjpeg.a libturbojpeg.a; do
        lipo=lipo
        for a in $ARCHS; do
            lipo="$lipo build-$a/INSTALL/lib/$i"
        done
        lipo="$lipo -create -output lib/$i"
        echo "$lipo"
        $lipo
    done
}

while (( "$#" )); do
    case "$1" in
        -sdk)
        sdkver="$2"
        shift
        ;;
        -clean)
        clean
        ;;
        *)
        srcdir="$1"
    esac
    shift
done

srcdir=$(absdir $srcdir)

case $sdkver in
    4.3)
    os=darwin10
    gccver=4.2.1
    ;;
    *)
    echo "Unsupported SDK version"
    exit 1
    ;;
esac

build
install

