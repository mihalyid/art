#
# Copyright (C) 2015 The Android Open Source Project
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
#

LOCAL_PATH := $(call my-dir)

include art/build/Android.common_build.mk

LIBARTBENCHMARK_COMMON_SRC_FILES := \
  jobject-benchmark/jobject_benchmark.cc \
  jni-perf/perf_jni.cc \
  scoped-primitive-array/scoped_primitive_array.cc

# $(1): target or host
define build-libartbenchmark
  ifneq ($(1),target)
    ifneq ($(1),host)
      $$(error expected target or host for argument 1, received $(1))
    endif
  endif

  art_target_or_host := $(1)

  include $(CLEAR_VARS)
  LOCAL_CPP_EXTENSION := $(ART_CPP_EXTENSION)
  LOCAL_MODULE := libartbenchmark
  ifeq ($$(art_target_or_host),target)
    LOCAL_MODULE_TAGS := tests
  endif
  LOCAL_SRC_FILES := $(LIBARTBENCHMARK_COMMON_SRC_FILES)
  LOCAL_SHARED_LIBRARIES += libart libbacktrace libnativehelper
  LOCAL_C_INCLUDES += $(ART_C_INCLUDES) art/runtime
  LOCAL_ADDITIONAL_DEPENDENCIES := art/build/Android.common_build.mk
  LOCAL_ADDITIONAL_DEPENDENCIES += $(LOCAL_PATH)/Android.mk
  ifeq ($$(art_target_or_host),target)
    LOCAL_CLANG := $(ART_TARGET_CLANG)
    $(call set-target-local-cflags-vars,debug)
    LOCAL_SHARED_LIBRARIES += libdl
    LOCAL_MULTILIB := both
    # LOCAL_MODULE_PATH_32 := $(ART_TARGET_OUT)/$(ART_TARGET_ARCH_32)
    # LOCAL_MODULE_PATH_64 := $(ART_TARGET_OUT)/$(ART_TARGET_ARCH_64)
    LOCAL_MODULE_TARGET_ARCH := $(ART_SUPPORTED_ARCH)
    include $(BUILD_SHARED_LIBRARY)
  else # host
    LOCAL_CLANG := $(ART_HOST_CLANG)
    LOCAL_CFLAGS := $(ART_HOST_CFLAGS) $(ART_HOST_DEBUG_CFLAGS)
    LOCAL_ASFLAGS := $(ART_HOST_ASFLAGS) $(ART_HOST_DEBUG_ASFLAGS)
    LOCAL_LDLIBS := -ldl -lpthread
    LOCAL_IS_HOST_MODULE := true
    LOCAL_MULTILIB := both
    include $(BUILD_HOST_SHARED_LIBRARY)
  endif

  # Clear locally used variables.
  art_target_or_host :=
endef

ifeq ($(ART_BUILD_TARGET),true)
  $(eval $(call build-libartbenchmark,target))
endif
ifeq ($(ART_BUILD_HOST),true)
  $(eval $(call build-libartbenchmark,host))
endif

# Clear locally used variables.
LOCAL_PATH :=
LIBARTBENCHMARK_COMMON_SRC_FILES :=
