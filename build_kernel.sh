#!/bin/bash

export ARCH=arm64
mkdir out

BUILD_CROSS_COMPILE=aarch64-linux-gnu-
CLANG_TRIPLE=aarch64-unknown-none-eabi

export CLANG_DIR="/usr/lib/llvm-16/bin/"
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"

#echo "**********************************"
#echo "Select variant (Snapdragon only)"
#echo "(1) 4G Variant"
#echo "(2) 5G Variant"
#read -p "Selected variant: " variant
CPU=$(($(nproc) - 1))

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE LLVM=1 CLANG_TRIPLE=$CLANG_TRIPLE r8q_defconfig

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE LLVM=1 CLANG_TRIPLE=$CLANG_TRIPLE CONFIG_DEBUG_SECTION_MISMATCH=y |tee ../compile.log

cat out/arch/arm64/boot/dts/vendor/qcom/*.dtb > out/dtb.img

DTB="out/dtb.img"

IMAGE="out/arch/arm64/boot/Image.gz"

if [[ -f "$IMAGE" ]]; then
	rm AnyKernel3/zImage > /dev/null 2>&1
	rm AnyKernel3/*.zip > /dev/null 2>&1
	cp $IMAGE AnyKernel3/Image.gz
	cp $DTB AnyKernel3/dtb
	cd AnyKernel3
	zip -r9 bandido-kernel-$(date +"%Y%m%d")-snapdragon.zip .
fi
