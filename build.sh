#!/bin/bash

# Initialize variables

GRN='\033[01;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[01;31m'
RST='\033[0m'
ORIGIN_DIR=$(pwd)
TOOLCHAIN=$ORIGIN_DIR/build-shit
IMAGE=$ORIGIN_DIR/out/arch/arm64/boot/Image.gz-dtb
DEVICE=RMX1821
CONFIG="${DEVICE}_defconfig"

# export environment variables
export_env_vars() {
    export KBUILD_BUILD_USER=Const
    export KBUILD_BUILD_HOST=Coccinelle
    export ARCH=arm64

    # CCACHE
    export USE_CCACHE=1
    export PATH="/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
}

script_echo() {
    echo "  $1"
}
exit_script() {
    kill -INT $$
}
add_deps() {
    echo -e "${CYAN}"
    if [ ! -d "$TOOLCHAIN" ]
    then
        script_echo "Create build-shit folder"
        mkdir "$TOOLCHAIN"
    fi

    if [ ! -d "$TOOLCHAIN" ]
    then
        script_echo "Downloading clang...."
        cd "$TOOLCHAIN" || exit
        git clone --depth=1 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r437112.git clang 2>&1 | sed 's/^/     /'
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 los-4.9-64 2>&1 | sed 's/^/     /'
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 los-4.9-32 2>&1 | sed 's/^/     /'
        cd ../
    fi
    verify_toolchain_install
}
verify_toolchain_install() {
    script_echo " "
    if [[ -d "${TOOLCHAIN}" ]]; then
        script_echo "I: Toolchain found at default location"
        export PATH="${TOOLCHAIN}/clang/bin:${PATH}:${TOOLCHAIN}/los-4.9-32/bin:${PATH}:${TOOLCHAIN}/los-4.9-64/bin:${PATH}"
    else
        script_echo "I: Toolchain not found"
        script_echo "   Downloading recommended toolchain at ${TOOLCHAIN}..."
        add_deps
    fi
}
build_kernel_image() {
    cleanup
    script_echo " "
    echo -e "${GRN}"
    read -p "Write the Kernel version: " KV
    echo -e "${YELLOW}"
    script_echo "Building CosmicFresh Kernel For $DEVICE"

    make -j$(($(nproc)+1)) ARCH=arm64 LOCALVERSION="—CosmicFresh-$DEVICE-R$KV" $CONFIG 2>&1 | sed 's/^/     /'
    make -j$(($(nproc)+1)) LOCALVERSION="—CosmicFresh-$DEVICE-R$KV" \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE="${TOOLCHAIN}/los-4.9-64/bin/aarch64-linux-android-" \
        CROSS_COMPILE_ARM32="${TOOLCHAIN}/los-4.9-32/bin/arm-linux-androideabi-" \
        CONFIG_NO_ERROR_ON_MISMATCH=y 2>&1 | sed 's/^/     /'
    SUCCESS=$?
    echo -e "${RST}"

    if [ $SUCCESS -eq 0 ] && [ -f "$IMAGE" ]
    then
        echo -e "${GRN}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation successful..."
        script_echo "Image can be found at out/arch/arm64/boot/Image.gz-dtb"
        script_echo  "------------------------------------------------------------"
        build_flashable_zip
    elif [ $SUCCESS -eq 130 ]
    then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Build force stopped by the user."
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
    elif [ $SUCCESS -eq 1 ]
    then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation failed..check build logs for errors"
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
        cleanup
    fi
}
build_flashable_zip() {
    script_echo " "
    script_echo "I: Building kernel image..."
    echo -e "${GRN}"
    cp "$ORIGIN_DIR"/out/arch/arm64/boot/Image.gz-dtb CosmicFresh/
    cd "$ORIGIN_DIR"/CosmicFresh/ || exit
    zip -r9 "CosmicFresh-$DEVICE-R$KV.zip" anykernel.sh META-INF tools version Image.gz-dtb
    rm -rf Image.gz-dtb
    cd ../
}

cleanup() {
    rm -rf "$ORIGIN_DIR"/out/arch/arm64/boot/{Image*,dt*}
    rm -rf "$ORIGIN_DIR"/CosmicFresh/{Image.gz-dtb,*.zip}
}
add_deps
export_env_vars
build_kernel_image