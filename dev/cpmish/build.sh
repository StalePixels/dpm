#!/bin/sh
# usage: dev/cpmish/build.sh CPMISH_DIR OUTDIR

set -e

if [ $# -ne 2 ]; then
    echo "usage: $0 CPMISH_DIR OUTDIR" >&2
    exit 1
fi

here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1" && pwd)
image=cpmish-build

if ! docker info > /dev/null 2>&1; then
    echo "$0: Docker is not running" >&2
    exit 1
fi

platform=linux/amd64

docker build --platform $platform -t $image "$here"

docker run --rm --platform $platform \
    -u "$(id -u):$(id -g)" \
    -v "$src:/src" \
    $image \
    make +dpm

mkdir -p "$2"
cp "$src"/.obj/dpm/*.com "$2"/
ls -l "$2"
