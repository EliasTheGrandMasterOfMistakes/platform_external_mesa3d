# Mesa 3-D graphics library
#
# Copyright (C) 2021 GlobalLogic Ukraine
# Copyright (C) 2021 Roman Stratiienko (r.stratiienko@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

ifneq ($(filter true, $(BOARD_MESA3D_USES_MESON_BUILD)),)

LOCAL_PATH := $(call my-dir)
MESA3D_TOP := $(dir $(LOCAL_PATH))

LIBDRM_VERSION = $(shell cat external/libdrm/meson.build | grep -o "\<version\>\s*:\s*'\w*\.\w*\.\w*'" | grep -o "\w*\.\w*\.\w*" | head -1)

MESA_VK_LIB_SUFFIX_amd := radeon
MESA_VK_LIB_SUFFIX_intel := intel
MESA_VK_LIB_SUFFIX_intel_hasvk := intel_hasvk
MESA_VK_LIB_SUFFIX_freedreno := freedreno
MESA_VK_LIB_SUFFIX_broadcom := broadcom
MESA_VK_LIB_SUFFIX_panfrost := panfrost
MESA_VK_LIB_SUFFIX_virtio := virtio
MESA_VK_LIB_SUFFIX_swrast := lvp

include $(CLEAR_VARS)

LOCAL_SHARED_LIBRARIES := libc libdl libdrm libm liblog libcutils libz libc++ libnativewindow libsync libhardware
LOCAL_STATIC_LIBRARIES := libexpat libarect libelf
LOCAL_HEADER_LIBRARIES := libnativebase_headers hwvulkan_headers
MESON_GEN_PKGCONFIGS := cutils expat hardware libdrm:$(LIBDRM_VERSION) nativewindow sync zlib:1.2.11 libelf
LOCAL_CFLAGS += $(BOARD_MESA3D_CFLAGS)

ifneq ($(filter swrast,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
ifeq ($(BOARD_MESA3D_FORCE_SOFTPIPE),)
MESON_GEN_LLVM_STUB := true
endif
endif

ifneq ($(filter zink,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libvulkan
MESON_GEN_PKGCONFIGS += vulkan
endif

ifneq ($(filter iris,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_intel
MESON_GEN_PKGCONFIGS += libdrm_intel:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
ifneq ($(MESON_GEN_LLVM_STUB),)
LOCAL_CFLAGS += -DFORCE_BUILD_AMDGPU   # instructs LLVM to declare LLVMInitializeAMDGPU* functions
# The flag is required for the Android-x86 LLVM port that follows the AOSP LLVM porting rules
# https://osdn.net/projects/android-x86/scm/git/external-llvm-project
endif
endif

ifneq ($(filter radeonsi amd,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_amdgpu
MESON_GEN_PKGCONFIGS += libdrm_amdgpu:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi r300 r600,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_radeon
MESON_GEN_PKGCONFIGS += libdrm_radeon:$(LIBDRM_VERSION)
endif

ifneq ($(filter d3d12,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_HEADER_LIBRARIES += DirectX-Headers
LOCAL_STATIC_LIBRARIES += DirectX-Guids
MESON_GEN_PKGCONFIGS += DirectX-Headers
endif

ifneq ($(MESON_GEN_LLVM_STUB),)
MESON_LLVM_VERSION := 12.0.0
LOCAL_SHARED_LIBRARIES += libLLVM12
endif

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
LOCAL_SHARED_LIBRARIES += \
    android.hardware.graphics.mapper@4.0 \
    libgralloctypes \
    libhidlbase \
    libutils

MESON_GEN_PKGCONFIGS += android.hardware.graphics.mapper:4.0
endif

__MY_SHARED_LIBRARIES := $(LOCAL_SHARED_LIBRARIES)

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
MESA_LIBGBM_NAME := libgbm_mesa
else
MESA_LIBGBM_NAME := libgbm
endif

ifeq ($(TARGET_IS_64_BIT),true)
LOCAL_MULTILIB := 64
else
LOCAL_MULTILIB := 32
endif
include $(LOCAL_PATH)/mesa3d_cross.mk

ifdef TARGET_2ND_ARCH
LOCAL_MULTILIB := 32
include $(LOCAL_PATH)/mesa3d_cross.mk
endif

#-------------------------------------------------------------------------------

# $1: name
# $2: additional symlinks
# $3: subdir
# $4: source prebuilt
# $5: export headers
define mesa3d-lib
include $(CLEAR_VARS)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE := $1
LOCAL_VENDOR_MODULE := true
LOCAL_MODULE_RELATIVE_PATH := $3
LOCAL_PREBUILT_MODULE_FILE := $($4)
LOCAL_MULTILIB := first
LOCAL_CHECK_ELF_FILES := false
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_SYMLINKS := $2
LOCAL_SHARED_LIBRARIES := $(__MY_SHARED_LIBRARIES)
LOCAL_EXPORT_C_INCLUDE_DIRS := $5
include $(BUILD_PREBUILT)

ifdef TARGET_2ND_ARCH
include $(CLEAR_VARS)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE := $1
LOCAL_VENDOR_MODULE := true
LOCAL_MODULE_RELATIVE_PATH := $3
LOCAL_PREBUILT_MODULE_FILE := $(2ND_$4)
LOCAL_MULTILIB := 32
LOCAL_CHECK_ELF_FILES := false
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_SYMLINKS := $2
LOCAL_SHARED_LIBRARIES := $(__MY_SHARED_LIBRARIES)
LOCAL_EXPORT_C_INCLUDE_DIRS := $5
include $(BUILD_PREBUILT)
endif
endef

ifneq ($(strip $(BOARD_MESA3D_GALLIUM_DRIVERS)),)
# Include hw specific dri symlinks in the build target, because Android needs
# to have a build target for every file which gets installed (even symlinks).
# Most drivers have the same symlink name as the driver is called. However,
# some do not. Overwrite them here:
MESA_DRI_SYMLNK_kmsro := armada-drm_dri.so etnaviv_dri.so exynos_dri.so \
                         gm12u320_dri.so hdlcd_dri.so hx8357d_dri.so \
                         ili9163_dri.so ili9225_dri.so ili9341_dri.so \
                         ili9486_dri.so imx-dcss_dri.so imx-drm_dri.so \
                         imx-lcdif_dri.so ingenic-drm_dri.so kirin_dri.so \
                         komeda_dri.so mali-dp_dri.so mcde_dri.so \
                         mediatek_dri.so meson_dri.so mi0283qt_dri.so \
                         mxsfb-drm_dri.so panel-mipi-dbi_dri.so pl111_dri.so \
                         rcar-du_dri.so repaper_dri.so rockchip_dri.so \
                         st7586_dri.so st7735r_dri.so sti_dri.so stm_dri.so \
                         sun4i-drm_dri.so udl_dri.so
MESA_DRI_SYMLNK_etnaviv := etnaviv_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_asahi := asahi_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_freedreno := msm_dri.so kgsl_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_lima := lima_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_panfrost := panfrost_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_v3d := v3d_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_vc4 := vc4_dri.so $(MESA_DRI_SYMLNK_kmsro)
MESA_DRI_SYMLNK_softpipe := swrast_dri.so
MESA_DRI_SYMLNK_svga := vmwgfx_dri.so
MESA_DRI_SYMLNK_virgl := virtio_gpu_dri.so
$(foreach driver,$(BOARD_MESA3D_GALLIUM_DRIVERS), $(eval MESA_DRI_SYMLNK_$(driver)?=$(driver)_dri.so))
$(foreach driver,$(BOARD_MESA3D_GALLIUM_DRIVERS), $(eval MESA_DRI_SYMLNKS_TMP+=$(MESA_DRI_SYMLNK_$(driver))))
# make this list unique
$(foreach _,$(MESA_DRI_SYMLNKS_TMP),$(if $(filter $_,$(MESA_DRI_SYMLNKS)),,$(eval MESA_DRI_SYMLNKS+=$_)))
# Module 'libgallium_dri', produces '/vendor/lib{64}/dri/libgallium_dri.so'
# This module also trigger DRI symlinks creation process
$(eval $(call mesa3d-lib,libgallium_dri,$(MESA_DRI_SYMLNKS),dri,MESA3D_GALLIUM_DRI_BIN))
# Module 'libglapi', produces '/vendor/lib{64}/libglapi.so'
$(eval $(call mesa3d-lib,libglapi,,,MESA3D_LIBGLAPI_BIN))

# Module 'libEGL_mesa', produces '/vendor/lib{64}/egl/libEGL_mesa.so'
$(eval $(call mesa3d-lib,libEGL_mesa,,egl,MESA3D_LIBEGL_BIN))
# Module 'libGLESv1_CM_mesa', produces '/vendor/lib{64}/egl/libGLESv1_CM_mesa.so'
$(eval $(call mesa3d-lib,libGLESv1_CM_mesa,,egl,MESA3D_LIBGLESV1_BIN))
# Module 'libGLESv2_mesa', produces '/vendor/lib{64}/egl/libGLESv2_mesa.so'
$(eval $(call mesa3d-lib,libGLESv2_mesa,,egl,MESA3D_LIBGLESV2_BIN))
endif

# Modules 'vulkan.{driver_name}', produces '/vendor/lib{64}/hw/vulkan.{driver_name}.so' HAL
$(foreach driver,$(BOARD_MESA3D_VULKAN_DRIVERS), \
    $(eval $(call mesa3d-lib,vulkan.$(MESA_VK_LIB_SUFFIX_$(driver)),,hw,MESA3D_VULKAN_$(driver)_BIN)))

ifneq ($(filter true, $(BOARD_MESA3D_BUILD_LIBGBM)),)
# Modules 'libgbm', produces '/vendor/lib{64}/libgbm.so'
$(eval $(call mesa3d-lib,$(MESA_LIBGBM_NAME),,,MESA3D_LIBGBM_BIN,$(MESA3D_TOP)/src/gbm/main))
endif

#-------------------------------------------------------------------------------

endif
