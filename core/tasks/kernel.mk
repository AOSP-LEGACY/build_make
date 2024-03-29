# Copyright (C) 2012 The CyanogenMod Project
#           (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Android makefile to build kernel as a part of Android Build
#
# Configuration
# =============
#
# These config vars are usually set in BoardConfig.mk:
#
#   TARGET_KERNEL_SOURCE               = Kernel source dir, optional, defaults
#                                          to kernel/$(TARGET_DEVICE_DIR)
#   TARGET_KERNEL_ADDITIONAL_FLAGS     = Additional make flags, optional
#   TARGET_KERNEL_ARCH                 = Kernel Arch
#   TARGET_KERNEL_CROSS_COMPILE_PREFIX = Compiler prefix (e.g. arm-eabi-)
#                                          defaults to arm-linux-androidkernel- for arm
#                                                      aarch64-linux-androidkernel- for arm64
#                                                      x86_64-linux-androidkernel- for x86
#
#   TARGET_KERNEL_CLANG_COMPILE        = Compile kernel with clang, defaults to false
#
#   KERNEL_TOOLCHAIN_PREFIX            = Overrides TARGET_KERNEL_CROSS_COMPILE_PREFIX,
#                                          Set this var in shell to override
#                                          toolchain specified in BoardConfig.mk
#   KERNEL_TOOLCHAIN                   = Path to toolchain, if unset, assumes
#                                          TARGET_KERNEL_CROSS_COMPILE_PREFIX
#                                          is in PATH
#   USE_CCACHE                         = Enable ccache (global Android flag)
#   TARGET_KERNEL_CONFIG               = Kernel defconfig
#   TARGET_KERNEL_VARIANT_CONFIG       = Variant defconfig, optional
#   TARGET_KERNEL_SELINUX_CONFIG       = SELinux defconfig, optional
#   TARGET_KERNEL_ADDITIONAL_CONFIG    = Additional defconfig, optional
#
#   TARGET_KERNEL_CLANG_COMPILE        = Compile kernel with clang, defaults to false
#
#   TARGET_KERNEL_CLANG_VERSION        = Clang prebuilts version, optional, defaults to clang-stable
#
#   TARGET_KERNEL_CLANG_PATH           = Clang prebuilts path, optional
#
#   BOARD_KERNEL_IMAGE_NAME            = Built image name
#                                          for ARM use: zImage
#                                          for ARM64 use: Image.gz
#                                          for uncompressed use: Image
#                                          If using an appended DT, append '-dtb'
#                                          to the end of the image name.
#                                          For example, for ARM devices,
#                                          use zImage-dtb instead of zImage.
#
#   KERNEL_CC                          = The C Compiler used. This is automatically set based
#                                          on whether the clang version is set, optional.
#
#   KERNEL_CLANG_TRIPLE                = Target triple for clang (e.g. aarch64-linux-gnu-)
#                                          defaults to arm-linux-gnu- for arm
#                                                      aarch64-linux-gnu- for arm64
#                                                      x86_64-linux-gnu- for x86
#
#   NEED_KERNEL_MODULE_ROOT            = Optional, if true, install kernel
#                                          modules in root instead of vendor
#   NEED_KERNEL_MODULE_SYSTEM          = Optional, if true, install kernel
#                                          modules in system instead of vendor

BUILD_TOP := $(shell pwd)

ifneq ($(TARGET_NO_KERNEL),true)

TARGET_AUTO_KDIR := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')
TARGET_KERNEL_SOURCE ?= $(TARGET_AUTO_KDIR)
ifneq ($(TARGET_PREBUILT_KERNEL),)
TARGET_KERNEL_SOURCE :=
endif

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := $(TARGET_ARCH)
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

# arm64 toolchain
KERNEL_TOOLCHAIN_arm64 := $(BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/aarch64/aarch64-linux-android-4.9/bin
ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    KERNEL_TOOLCHAIN_PREFIX_arm64 := aarch64-linux-android-
else
    KERNEL_TOOLCHAIN_PREFIX_arm64 := aarch64-linux-androidkernel-
endif
# arm toolchain
KERNEL_TOOLCHAIN_arm := $(BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/arm/arm-linux-androideabi-4.9/bin
KERNEL_TOOLCHAIN_PREFIX_arm := arm-linux-androidkernel-
# x86 toolchain
KERNEL_TOOLCHAIN_x86 := $(BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/x86/x86_64-linux-android-4.9/bin
KERNEL_TOOLCHAIN_PREFIX_x86 := x86_64-linux-androidkernel-

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifneq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_TOOLCHAIN_PREFIX ?= $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
else
KERNEL_TOOLCHAIN ?= $(KERNEL_TOOLCHAIN_$(KERNEL_ARCH))
KERNEL_TOOLCHAIN_PREFIX ?= $(KERNEL_TOOLCHAIN_PREFIX_$(KERNEL_ARCH))
endif

ifeq ($(KERNEL_TOOLCHAIN),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN_PREFIX)
else ifneq ($(KERNEL_TOOLCHAIN_PREFIX),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN)/$(KERNEL_TOOLCHAIN_PREFIX)
endif

ifneq ($(USE_CCACHE),)
    ifneq ($(CCACHE_EXEC),)
        # Android 10+ deprecates use of a build ccache. Only system installed ones are now allowed
        CCACHE_BIN := $(CCACHE_EXEC)
    endif
endif

ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(KERNEL_TOOLCHAIN_PATH)"
else
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(CCACHE_BIN) $(KERNEL_TOOLCHAIN_PATH)"
endif

# Needed for CONFIG_COMPAT_VDSO, safe to set for all arm64 builds
ifeq ($(KERNEL_ARCH),arm64)
   KERNEL_CROSS_COMPILE += CROSS_COMPILE_ARM32="$(KERNEL_TOOLCHAIN_arm)/arm-linux-androideabi-"
endif

# Clear this first to prevent accidental poisoning from env
KERNEL_MAKE_FLAGS :=

# Add back threads, ninja cuts this to $(nproc)/2
KERNEL_MAKE_FLAGS += -j

ifeq ($(KERNEL_ARCH),arm)
  # Avoid "Unknown symbol _GLOBAL_OFFSET_TABLE_" errors
  KERNEL_MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifeq ($(KERNEL_ARCH),arm64)
  # Avoid "unsupported RELA relocation: 311" errors (R_AARCH64_ADR_GOT_PAGE)
  KERNEL_MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifeq ($(HOST_OS),darwin)
  KERNEL_MAKE_FLAGS += C_INCLUDE_PATH=$(BUILD_TOP)/external/elfutils/libelf:/usr/local/opt/openssl/include
  KERNEL_MAKE_FLAGS += LIBRARY_PATH=/usr/local/opt/openssl/lib
else
  KERNEL_MAKE_FLAGS += C_INCLUDE_PATH=$(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/include
  KERNEL_MAKE_FLAGS += LIBRARY_PATH=$(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu
  KERNEL_MAKE_FLAGS += HOSTCFLAGS="-L $(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu"
  KERNEL_MAKE_FLAGS += HOSTLDFLAGS="-L $(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu"
endif

ifneq ($(TARGET_KERNEL_ADDITIONAL_FLAGS),)
  KERNEL_MAKE_FLAGS += $(TARGET_KERNEL_ADDITIONAL_FLAGS)
endif

# Set DTBO image locations so the build system knows to build them
ifeq ($(TARGET_NEEDS_DTBOIMAGE),true)
BOARD_PREBUILT_DTBOIMAGE ?= $(PRODUCT_OUT)/dtbo/arch/$(KERNEL_ARCH)/boot/dtbo.img
else ifeq ($(BOARD_KERNEL_SEPARATED_DTBO),true)
BOARD_PREBUILT_DTBOIMAGE ?= $(PRODUCT_OUT)/dtbo-pre.img
endif

# Set use the full path to the make command
KERNEL_MAKE_CMD := $(BUILD_TOP)/prebuilts/build-tools/$(HOST_OS)-x86/bin/make

# Set the full path to the gcc command
GCC_PREBUILTS := $(BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/host
ifeq ($(HOST_OS),darwin)
KERNEL_HOST_TOOLCHAIN_ROOT := $(GCC_PREBUILTS)/i686-apple-darwin-4.2.1/bin/i686-apple-darwin11-
else
KERNEL_HOST_TOOLCHAIN_ROOT := $(GCC_PREBUILTS)/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-
endif
KERNEL_MAKE_FLAGS += HOSTCC=$(KERNEL_HOST_TOOLCHAIN_ROOT)gcc
KERNEL_MAKE_FLAGS += HOSTCXX=$(KERNEL_HOST_TOOLCHAIN_ROOT)g++

## Externally influenced variables
KERNEL_SRC := $(TARGET_KERNEL_SOURCE)

# kernel configuration - mandatory
KERNEL_DEFCONFIG := $(TARGET_KERNEL_CONFIG)
VARIANT_DEFCONFIG := $(TARGET_KERNEL_VARIANT_CONFIG)
SELINUX_DEFCONFIG := $(TARGET_KERNEL_SELINUX_CONFIG)

## Internal variables
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
KERNEL_RELEASE := $(KERNEL_OUT)/include/config/kernel.release

KERNEL_HEADERS_INSTALL_DIR := $(KERNEL_OUT)/usr
KERNEL_HEADERS_INSTALL_DEPS := $(KERNEL_OUT)/.headers_install_deps

ifeq ($(KERNEL_ARCH),x86_64)
KERNEL_DEFCONFIG_ARCH := x86
else
KERNEL_DEFCONFIG_ARCH := $(KERNEL_ARCH)
endif
KERNEL_DEFCONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_DEFCONFIG_ARCH)/configs/$(KERNEL_DEFCONFIG)

ifeq ($(BOARD_KERNEL_IMAGE_NAME),)
$(error BOARD_KERNEL_IMAGE_NAME not defined.)
endif
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/$(BOARD_KERNEL_IMAGE_NAME)

ifneq ($(TARGET_KERNEL_ADDITIONAL_CONFIG),)
KERNEL_ADDITIONAL_CONFIG := $(TARGET_KERNEL_ADDITIONAL_CONFIG)
KERNEL_ADDITIONAL_CONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG)
    ifeq ("$(wildcard $(KERNEL_ADDITIONAL_CONFIG_SRC))","")
        $(warning TARGET_KERNEL_ADDITIONAL_CONFIG '$(TARGET_KERNEL_ADDITIONAL_CONFIG)' doesnt exist)
        KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
    endif
else
    KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
endif

ifeq "$(wildcard $(KERNEL_SRC) )" ""
    ifneq ($(TARGET_PREBUILT_KERNEL),)
        HAS_PREBUILT_KERNEL := true
        NEEDS_KERNEL_COPY := true
    else
        $(foreach cf,$(PRODUCT_COPY_FILES), \
            $(eval _src := $(call word-colon,1,$(cf))) \
            $(eval _dest := $(call word-colon,2,$(cf))) \
            $(ifeq kernel,$(_dest), \
                $(eval HAS_PREBUILT_KERNEL := true)))
    endif

    ifneq ($(HAS_PREBUILT_KERNEL),)
        $(warning ***************************************************************)
        $(warning * Using prebuilt kernel binary instead of source              *)
        $(warning * THIS IS DEPRECATED, AND WILL BE DISCONTINUED                *)
        $(warning * Please configure your device to download the kernel         *)
        $(warning * source repository to $(KERNEL_SRC))
        $(warning * for more information                                        *)
        $(warning ***************************************************************)
        FULL_KERNEL_BUILD := false
        KERNEL_BIN := $(TARGET_PREBUILT_KERNEL)
    else
        $(warning ***************************************************************)
        $(warning *                                                             *)
        $(warning * No kernel source found, and no fallback prebuilt defined.   *)
        $(warning * Please make sure your device is properly configured to      *)
        $(warning * download the kernel repository to $(KERNEL_SRC))
        $(warning * and add the TARGET_KERNEL_CONFIG variable to BoardConfig.mk *)
        $(warning *                                                             *)
        $(warning * As an alternative, define the TARGET_PREBUILT_KERNEL        *)
        $(warning * variable with the path to the prebuilt binary kernel image  *)
        $(warning * in your BoardConfig.mk file                                 *)
        $(warning *                                                             *)
        $(warning ***************************************************************)
        $(error "NO KERNEL")
    endif
else
    NEEDS_KERNEL_COPY := true
    ifeq ($(TARGET_KERNEL_CONFIG),)
        $(warning **********************************************************)
        $(warning * Kernel source found, but no configuration was defined  *)
        $(warning * Please add the TARGET_KERNEL_CONFIG variable to your   *)
        $(warning * BoardConfig.mk file                                    *)
        $(warning **********************************************************)
        # $(error "NO KERNEL CONFIG")
    else
        #$(info Kernel source found, building it)
        FULL_KERNEL_BUILD := true
        KERNEL_BIN := $(TARGET_PREBUILT_INT_KERNEL)
    endif
endif

ifeq ($(FULL_KERNEL_BUILD),true)

ifeq ($(NEED_KERNEL_MODULE_ROOT),true)
KERNEL_MODULES_OUT := $(TARGET_ROOT_OUT)
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_recovery)
KERNEL_MODULE_MOUNTPOINT :=
else ifeq ($(NEED_KERNEL_MODULE_SYSTEM),true)
KERNEL_MODULES_OUT := $(TARGET_OUT)
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_system)
KERNEL_MODULE_MOUNTPOINT := system
else
KERNEL_MODULES_OUT := $(TARGET_OUT_VENDOR)
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_vendor)
KERNEL_MODULE_MOUNTPOINT := vendor
endif
MODULES_INTERMEDIATES := $(call intermediates-dir-for,PACKAGING,kernel_modules)

ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    ifneq ($(TARGET_KERNEL_CLANG_VERSION),)
        # Find the clang-* directory containing the specified version
        KERNEL_CLANG_VERSION := $(shell find $(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/ -name AndroidVersion.txt -exec grep -l $(TARGET_KERNEL_CLANG_VERSION) "{}" \; | sed -e 's|/AndroidVersion.txt$$||g;s|^.*/||g')
    else
        # Use the default version of clang if TARGET_KERNEL_CLANG_VERSION hasn't been set by the device config
        KERNEL_CLANG_VERSION := $(LLVM_PREBUILTS_VERSION)
    endif
    TARGET_KERNEL_CLANG_PATH ?= $(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/$(KERNEL_CLANG_VERSION)/bin
    ifeq ($(KERNEL_ARCH),arm64)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=aarch64-linux-gnu-
    else ifeq ($(KERNEL_ARCH),arm)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=arm-linux-gnu-
    else ifeq ($(KERNEL_ARCH),x86)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=x86_64-linux-gnu-
    endif
    PATH_OVERRIDE := PATH=$(TARGET_KERNEL_CLANG_PATH):$$PATH LD_LIBRARY_PATH=$(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/$(KERNEL_CLANG_VERSION)/lib64:$$LD_LIBRARY_PATH
    ifeq ($(KERNEL_CC),)
        KERNEL_CC := CC="$(CCACHE_BIN) clang"
    endif
endif

ifeq ($(TARGET_KERNEL_MODULES),)
    TARGET_KERNEL_MODULES := INSTALLED_KERNEL_MODULES
endif

# System tools are no longer allowed on 10+
PATH_OVERRIDE += PATH=$(BUILD_TOP)/prebuilts/tools-lineage/$(HOST_OS)-x86/bin:$$PATH LD_LIBRARY_PATH=$(BUILD_TOP)/prebuilts/tools-lineage/$(HOST_OS)-x86/lib:$$LD_LIBRARY_PATH

KERNEL_ADDITIONAL_CONFIG_OUT := $(KERNEL_OUT)/.additional_config

# Internal implementation of make-kernel-target
# $(1): output path (The value passed to O=)
# $(2): target to build (eg. defconfig, modules, dtbo.img)
define internal-make-kernel-target
$(PATH_OVERRIDE) $(KERNEL_MAKE_CMD) $(KERNEL_MAKE_FLAGS) -C $(KERNEL_SRC) O=$(1) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) $(2)
endef

# Make a kernel target
# $(1): The kernel target to build (eg. defconfig, modules, modules_install)
define make-kernel-target
$(call internal-make-kernel-target,$(KERNEL_OUT),$(1))
endef

# Make a DTBO target
# $(1): The DTBO target to build (eg. dtbo.img, defconfig)
define make-dtbo-target
$(call internal-make-kernel-target,$(PRODUCT_OUT)/dtbo,$(1))
endef

$(KERNEL_ADDITIONAL_CONFIG_OUT):
	$(hide) cmp -s $(KERNEL_ADDITIONAL_CONFIG_SRC) $@ || cp $(KERNEL_ADDITIONAL_CONFIG_SRC) $@;

$(KERNEL_CONFIG): $(KERNEL_DEFCONFIG_SRC) $(KERNEL_ADDITIONAL_CONFIG_OUT)
	@echo "Building Kernel Config"
	$(hide) mkdir -p $(KERNEL_OUT)
	$(call make-kernel-target,VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) $(KERNEL_DEFCONFIG))
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding kernel config with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(call make-kernel-target,oldconfig); \
		fi
	# Create defconfig build artifact
	$(call make-kernel-target,savedefconfig)
	$(hide) if [ ! -z "$(KERNEL_ADDITIONAL_CONFIG)" ]; then \
			echo "Using additional config '$(KERNEL_ADDITIONAL_CONFIG)'"; \
			$(KERNEL_SRC)/scripts/kconfig/merge_config.sh -m -O $(KERNEL_OUT) $(KERNEL_OUT)/.config $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG); \
			$(call make-kernel-target,KCONFIG_ALLCONFIG=$(KERNEL_OUT)/.config alldefconfig); \
		fi

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_CONFIG)
	@echo "Building Kernel"
	$(call make-kernel-target,$(BOARD_KERNEL_IMAGE_NAME))
	$(hide) if grep -q '^CONFIG_OF=y' $(KERNEL_CONFIG); then \
			echo "Building DTBs"; \
			$(call make-kernel-target,dtbs); \
		fi
	$(hide) if grep -q '=m' $(KERNEL_CONFIG); then \
			echo "Building Kernel Modules"; \
			$(call make-kernel-target,modules); \
		fi

.PHONY: INSTALLED_KERNEL_MODULES
INSTALLED_KERNEL_MODULES: depmod-host
	$(hide) if grep -q '=m' $(KERNEL_CONFIG); then \
			echo "Installing Kernel Modules"; \
			$(call make-kernel-target,INSTALL_MOD_PATH=$(MODULES_INTERMEDIATES) modules_install); \
			kernel_release=$$(cat $(KERNEL_RELEASE)) \
			modules=$$(find $(MODULES_INTERMEDIATES)/lib/modules/$$kernel_release -type f -name '*.ko'); \
			for f in $$modules; do \
				$(KERNEL_TOOLCHAIN_PATH)strip --strip-unneeded $$f; \
			done; \
			($(call build-image-kernel-modules,$$modules,$(KERNEL_MODULES_OUT),$(KERNEL_MODULE_MOUNTPOINT)/,$(KERNEL_DEPMOD_STAGING_DIR))); \
		fi

$(TARGET_KERNEL_MODULES): $(TARGET_PREBUILT_INT_KERNEL)

# Install kernel (uapi) headers.
#
# The dependency file serves two purposes:
#  - It is a stamp indicating when the headers were last installed.
#  - It contains a rule to regenerate itself when any kernel header
#    files change.  This rule is identical to the rule emitted by
#    GCC using the M/MM flags.
#
# Note that the location of installed kernel headers changed when the
# kernel uapi system was introduced in 3.7.  Unfortunately, it is not
# sufficient to test whether the uapi directories exist because some
# kernels backport patches that contain uapi headers.  So we look for
# the string "version_h" in the kernel makefile which was introduced
# as a part of the uapi system (commit d183e6f570f3).
-include $(KERNEL_HEADERS_INSTALL_DEPS)
$(KERNEL_HEADERS_INSTALL_DEPS):
	@echo "Building Kernel Headers"
	$(hide) mkdir -p $(KERNEL_OUT)
	$(hide) rm -f $@
	$(call make-kernel-target,headers_install)
	$(hide) echo "$@: \\" > $@
	$(hide) ( cd $(KERNEL_SRC); \
		if grep -q '^version_h' 'Makefile'; then \
			depdirs="arch/$(KERNEL_ARCH)/include/uapi include/uapi"; \
		else \
			depdirs="arch/$(KERNEL_ARCH)/include/asm include"; \
		fi; \
		deps="Makefile $$(find $$depdirs -type f -name '*.h')"; \
		for f in $$deps; do \
			echo "  $(KERNEL_SRC)/$$f \\" >> $@; \
		done ; \
		echo "" >> $@ ; \
		for f in $$deps; do \
			echo "$(KERNEL_SRC)/$$f:" >> $@; \
			echo "" >> $@; \
		done \
		)

.PHONY: INSTALLED_KERNEL_HEADERS
INSTALLED_KERNEL_HEADERS: $(KERNEL_HEADERS_INSTALL_DEPS)

# Dependencies on $(KERNEL_OUT)/usr are deprecated
$(KERNEL_HEADERS_INSTALL_DIR): $(KERNEL_HEADERS_INSTALL_DEPS)
	@echo "Depending on $(KERNEL_HEADERS_INSTALL_DIR) is deprecated." 1>&2
	@echo "Use INSTALLED_KERNEL_HEADERS instead." 1>&2
	@exit 1


.PHONY: kerneltags
kerneltags: $(KERNEL_CONFIG)
	$(hide) mkdir -p $(KERNEL_OUT)
	$(call make-kernel-target,tags)

.PHONY: kernelsavedefconfig alldefconfig

kernelsavedefconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
	$(call make-kernel-target,$(KERNEL_DEFCONFIG))
	env KCONFIG_NOTIMESTAMP=true \
		 $(call make-kernel-target,savedefconfig)
	cp $(KERNEL_OUT)/defconfig $(KERNEL_DEFCONFIG_SRC)

alldefconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
	env KCONFIG_NOTIMESTAMP=true \
		 $(call make-kernel-target,alldefconfig)

ifeq ($(TARGET_NEEDS_DTBOIMAGE),true)
BOARD_PREBUILT_DTBOIMAGE = $(PRODUCT_OUT)/dtbo/arch/$(KERNEL_ARCH)/boot/dtbo.img
$(BOARD_PREBUILT_DTBOIMAGE):
	echo -e ${CL_GRN}"Building DTBO.img"${CL_RST}
	$(call make-dtbo-target,$(KERNEL_DEFCONFIG))
	$(call make-dtbo-target,dtbo.img)
endif # TARGET_NEEDS_DTBOIMAGE

endif # FULL_KERNEL_BUILD

## Install it

ifeq ($(NEEDS_KERNEL_COPY),true)
file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(KERNEL_BIN) | $(ACP)
	$(transform-prebuilt-to-target)

ALL_PREBUILT += $(INSTALLED_KERNEL_TARGET)
endif

INSTALLED_DTBOIMAGE_TARGET := $(PRODUCT_OUT)/dtbo.img
ALL_PREBUILT += $(INSTALLED_DTBOIMAGE_TARGET)

.PHONY: kernel
kernel: $(INSTALLED_KERNEL_TARGET) $(TARGET_KERNEL_MODULES)

.PHONY: dtboimage
dtboimage: $(INSTALLED_DTBOIMAGE_TARGET)

endif # TARGET_NO_KERNEL

