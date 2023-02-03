#!/bin/bash

unset LLVM
export ARCH=arm64
mkdir -p out

BUILD_CROSS_COMPILE=/root/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf/bin/aarch64-none-elf-
CLANG_TRIPLE=aarch64-unknown-none-eabi

export CLANG_DIR="/usr/lib/llvm-16/bin/"
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"
#export LLVM=1

CPU=$(($(nproc) - 1))

DATE_START=$(date +"%s")
IMAGE="out/arch/arm64/boot/Image.gz"
DTB="out/dtb.img"

# remove a previous kernel image
rm $IMAGE &> /dev/null

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE r8q_defconfig

scripts/configcleaner "CONFIG_THINLTO
CONFIG_LTO_GCC
CONFIG_LTO_CLANG
CONFIG_HAVE_ARCH_PREL32_RELOCATIONS
"

if [[ -v LLVM ]]; then
	echo -e "\nCONFIG_LTO_CLANG=y\n" >> out/.config
	echo -e "\n# CONFIG_LTO_GCC is not set\n" >> out/.config
   case $1 in
   lto)
        echo -e "\n################# Compiling FULL CLANG LTO build #################\n"
        echo -e "\n# CONFIG_THINLTO is not set\n" >> out/.config
   ;;

   *)
        echo -e "\nCONFIG_THINLTO=y\n" >> out/.config
   ;;
   esac
else
   case $1 in
   lto)
        echo -e "\n################# Compiling FULL GCC LTO build #################\n"
        echo -e "\nCONFIG_LTO_GCC=y\n" >> out/.config
	echo -e "\n# nCONFIG_HAVE_ARCH_PREL32_RELOCATIONS is not set\n" >> out/.config
   ;;

   *)
        echo -e "\n# CONFIG_LTO_GCC is not set\n" >> out/.config
	echo -e "\nCONFIG_HAVE_ARCH_PREL32_RELOCATIONS=y\n" >> out/.config
   ;;
   esac
fi

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE oldconfig
make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE 2>&1 |tee ../compile-bandido.log


if [[ -f "$IMAGE" ]]; then
	STATE=`adb get-state`
	if [[ $STATE != "recovery" ]]; then
		adb reboot recovery
	fi
	KERNELZIP="bandido-kernel-$(date +"%Y%m%d%H%M").zip"
	cat out/arch/arm64/boot/dts/vendor/qcom/*.dtb > $DTB
	rm AnyKernel3/zImage > /dev/null 2>&1
	rm AnyKernel3/*.zip > /dev/null 2>&1
	cp $IMAGE AnyKernel3/Image.gz
	cp $DTB AnyKernel3/dtb
	cd AnyKernel3

	zip -r9 $KERNELZIP .

	DATE_END=$(date +"%s")
	DIFF=$(($DATE_END - $DATE_START))

	echo -e "\nTime elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.\n"
	adb wait-for-recovery
	adb push $KERNELZIP /sdcard/
else
	echo -e "ERROR\n"
fi
