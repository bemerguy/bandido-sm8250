#!/bin/bash

unset LLVM

#BUILD_CROSS_COMPILE=/root/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf/bin/aarch64-none-elf-
BUILD_CROSS_COMPILE=/root/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
#BUILD_CROSS_COMPILE=/home/me/x-tools/aarch64-linux-gnu/bin/aarch64-linux-gnu-

#uncomment those to use clang instead
export LLVM=1
export CLANG_DIR="/usr/lib/llvm-18/bin/"

#######################################
mkdir -p out
export ARCH=arm64
CLANG_TRIPLE=aarch64-unknown-none-eabi
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc"

CPU=$(nproc)

DATE_START=$(date +"%s")
IMAGE="out/arch/arm64/boot/Image.gz"

# remove a previous kernel image
rm $IMAGE &> /dev/null

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE r8q_defconfig

scripts/configcleaner "CONFIG_THINLTO
CONFIG_LTO_GCC
CONFIG_LTO_CLANG
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
   ;;

   *)
        echo -e "\n# CONFIG_LTO_GCC is not set\n" >> out/.config
   ;;
   esac
fi

make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE \
	CLANG_TRIPLE=$CLANG_TRIPLE oldconfig
make -j$CPU -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE \
	CLANG_TRIPLE=$CLANG_TRIPLE 2>&1 |tee ../compile-bandido.log


if [[ -f "$IMAGE" ]]; then
	STATE=`adb get-state`
	if [[ $STATE != "recovery" ]]; then
		adb reboot recovery
	fi
	KERNELZIP="bandido-kernel-$(date +"%Y%m%d%H%M").zip"
	rm AnyKernel3/dtb* > /dev/null 2>&1
	rm AnyKernel3/*Image* > /dev/null 2>&1
	rm AnyKernel3/*.zip > /dev/null 2>&1
	cp $IMAGE AnyKernel3/
        cat out/arch/arm64/boot/dts/vendor/qcom/*.dtb > AnyKernel3/dtb
#	DTBO_FILES=$(find $(pwd)/out/arch/arm64/boot/dts/samsung/ -name kona-sec-*-r*.dtbo)
#	$(pwd)/tools/mkdtimg create $(pwd)/AnyKernel3/dtbo.img --page_size=4096 ${DTBO_FILES}

	cd AnyKernel3

	zip -r9 $KERNELZIP . -x .git README.md *placeholder

	DATE_END=$(date +"%s")
	DIFF=$(($DATE_END - $DATE_START))

	echo -e "\nTime elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.\n"
	adb wait-for-recovery
	adb push $KERNELZIP /sdcard/
else
	echo -e "\nERROR. Something broke along the way since $IMAGE is not there\n"
fi
