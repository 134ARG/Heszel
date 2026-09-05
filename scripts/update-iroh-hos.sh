#!/usr/bin/env sh
set -eu
# OHOS_SDK_NATIVE_ROOT=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HESZEL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
IROH_ROOT="$HESZEL_ROOT/third-party/iroh-heszel"
BUILD_SCRIPT="$IROH_ROOT/crates/hos/build-ohos.sh"
GENERATED_CPP="$IROH_ROOT/target/iroh-hos-ohos/entry/src/main/cpp"
APP_CPP="$HESZEL_ROOT/entry/src/main/cpp"
IROH_RUST_TOOLCHAIN=${RUST_TOOLCHAIN:-1.91.0}
IROH_RUST_TARGET=aarch64-unknown-linux-ohos

if [ ! -x "$BUILD_SCRIPT" ]; then
    echo "iroh-heszel submodule is missing." >&2
    echo "Initialize it with: git submodule update --init third-party/iroh-heszel" >&2
    exit 1
fi

rustup target add --toolchain "$IROH_RUST_TOOLCHAIN" "$IROH_RUST_TARGET"
"$BUILD_SCRIPT"

if [ ! -d "$GENERATED_CPP/iroh_hos" ] || [ ! -d "$GENERATED_CPP/types/libiroh_hos" ]; then
    echo "Expected HarmonyOS build output was not generated at: $GENERATED_CPP" >&2
    exit 1
fi

mkdir -p "$APP_CPP/types"
cp -R "$GENERATED_CPP/iroh_hos" "$APP_CPP/"
cp -R "$GENERATED_CPP/types/libiroh_hos" "$APP_CPP/types/"

echo "Updated Heszel's iroh-hos native module from the iroh-heszel submodule."
