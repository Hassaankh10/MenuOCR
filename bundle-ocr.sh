#!/bin/bash
# PNG-only static OCR build: screenshots do not need TIFF/JPEG/network dependencies.
set -euo pipefail
cd "$(dirname "$0")"
CMAKE_BIN="${CMAKE_BIN:-cmake}"
ROOT="$PWD/.build/ocr"
PREFIX="$ROOT/install"
SDK="$(xcrun --show-sdk-path)"
mkdir -p "$ROOT/src"
fetch() {
    local name="$1" repo="$2" tag="$3" hash="$4"
    if [[ ! -d "$ROOT/src/$name" ]]; then
        curl -fL --retry 2 --max-time 120 "https://api.github.com/repos/$repo/tarball/$tag" -o "$ROOT/$name.tgz"
        echo "$hash  $ROOT/$name.tgz" | shasum -a 256 -c -
        mkdir -p "$ROOT/src/$name"
        tar -xzf "$ROOT/$name.tgz" -C "$ROOT/src/$name" --strip-components=1
    fi
}
if [[ ! -x "$PREFIX/bin/tesseract" ]]; then
    fetch png pnggroup/libpng v1.6.50 48d1e722e299a22d55e7bec91eeab3fed67ce3b7825f588123b27a0a8d793445
    fetch leptonica DanBloomberg/leptonica 1.85.0 c5644385a691cd0bd2f43d01f386620142e7a0d54712b1a8defdfdc997ba3e66
    fetch tesseract tesseract-ocr/tesseract 5.5.1 80e6dc6ba6cdf1951324149c6f6471542fdf36ca1ec22ca9020e708588deeb7c
    common=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DZLIB_LIBRARY="$SDK/usr/lib/libz.tbd" -DZLIB_INCLUDE_DIR="$SDK/usr/include")
    "$CMAKE_BIN" -S "$ROOT/src/png" -B "$ROOT/png-build" "${common[@]}" -DPNG_FRAMEWORK=OFF -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF
    "$CMAKE_BIN" --build "$ROOT/png-build" --parallel 6
    "$CMAKE_BIN" --install "$ROOT/png-build"
    "$CMAKE_BIN" -S "$ROOT/src/leptonica" -B "$ROOT/lept-build" "${common[@]}" -DBUILD_PROG=OFF -DENABLE_GIF=OFF -DENABLE_JPEG=OFF -DENABLE_TIFF=OFF -DENABLE_WEBP=OFF -DENABLE_OPENJPEG=OFF
    "$CMAKE_BIN" --build "$ROOT/lept-build" --parallel 6
    "$CMAKE_BIN" --install "$ROOT/lept-build"
    "$CMAKE_BIN" -S "$ROOT/src/tesseract" -B "$ROOT/tess-build" "${common[@]}" -DBUILD_TRAINING_TOOLS=OFF -DGRAPHICS_DISABLED=ON -DDISABLE_TIFF=ON -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON -DENABLE_NATIVE=OFF -DOPENMP_BUILD=OFF
    "$CMAKE_BIN" --build "$ROOT/tess-build" --parallel 6
    "$CMAKE_BIN" --install "$ROOT/tess-build"
fi
DEST="${1:-$PWD/dist/MenuOCR.app/Contents/Resources/OCR}"
mkdir -p "$DEST/bin" "$DEST/share/tessdata" "$DEST/Licenses"
cp "$PREFIX/bin/tesseract" "$DEST/bin/"
strip "$DEST/bin/tesseract"
if otool -L "$DEST/bin/tesseract" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/)' ; then echo 'Unexpected external OCR library dependency' >&2; exit 1; fi
vtool -show-build "$DEST/bin/tesseract" | grep -q 'minos 13.0'
cp "$ROOT/src/tesseract/LICENSE" "$DEST/Licenses/Tesseract.txt"
cp "$ROOT/src/leptonica/leptonica-license.txt" "$DEST/Licenses/Leptonica.txt"
cp "$ROOT/src/png/LICENSE" "$DEST/Licenses/libpng.txt"
cp -R "$PREFIX/share/tessdata/configs" "$DEST/share/tessdata/"
MODEL="$ROOT/eng.traineddata"
if [[ ! -f "$MODEL" ]]; then curl -fL --retry 2 --max-time 120 https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/65727574dfcd264acbb0c3e07860e4e9e9b22185/eng.traineddata -o "$MODEL"; fi
echo "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2  $MODEL" | shasum -a 256 -c -
cp "$MODEL" "$DEST/share/tessdata/"
echo "Bundled OCR at $DEST"
