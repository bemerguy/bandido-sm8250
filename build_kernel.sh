#!/bin/bash

export ARCH=arm64
mkdir -p out

BUILD_CROSS_COMPILE=aarch64-linux-gnu-
CLANG_TRIPLE=aarch64-unknown-none-eabi

export CLANG_DIR="/usr/lib/llvm-16/bin/"
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"
export LLVM=1


CPU=$(($(nproc) - 1))

DATE_START=$(date +"%s")
IMAGE="out/arch/arm64/boot/Image.gz"

# remove a previous kernel image
rm $IMAGE &> /dev/null

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE r8q_defconfig

scripts/configcleaner CONFIG_THINLTO

case $1 in
   lto)
	echo -e "################# Compiling LTO build #################\n"
	echo -e "\n# CONFIG_THINLTO is not set\n" >> out/.config
   ;;

   *)
	echo -e "\nCONFIG_THINLTO=y\n" >> out/.config
   ;;
esac

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE oldconfig
make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE 2>&1 |tee ../compile.log


if [[ -f "$IMAGE" ]]; then
	DTB="out/dtb.img"
	cat out/arch/arm64/boot/dts/vendor/qcom/*.dtb > $DTB
	rm AnyKernel3/zImage > /dev/null 2>&1
	rm AnyKernel3/*.zip > /dev/null 2>&1
	cp $IMAGE AnyKernel3/Image.gz
	cp $DTB AnyKernel3/dtb
	cd AnyKernel3
	zip -r9 bandido-kernel-$(date +"%Y%m%d%H%M").zip .
fi

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))

echo -e "\nTime wasted: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.\n"
