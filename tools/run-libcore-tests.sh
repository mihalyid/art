#!/bin/bash
#
# Copyright (C) 2014 The Android Open Source Project
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

if [ ! -d libcore ]; then
  echo "Script needs to be run at the root of the android tree"
  exit 1
fi

if [ -z "$ANDROID_PRODUCT_OUT" ] ; then
  JAVA_LIBRARIES=out/target/common/obj/JAVA_LIBRARIES
else
  JAVA_LIBRARIES=${ANDROID_PRODUCT_OUT}/../../common/obj/JAVA_LIBRARIES
fi

function cparg {
  for var
  do
    printf -- "--classpath ${JAVA_LIBRARIES}/${var}_intermediates/classes.jack ";
  done
}

DEPS="core-tests jsr166-tests mockito-target"

for lib in $DEPS
do
  if [ ! -f "${JAVA_LIBRARIES}/${lib}_intermediates/classes.jack" ]; then
    echo "${lib} is missing. Before running, you must run art/tools/buildbot-build.sh"
    exit 1
  fi
done

expectations="--expectations art/tools/libcore_failures.txt"
if [ "x$ART_USE_READ_BARRIER" = xtrue ]; then
  # Tolerate some more failures on the concurrent collector configurations.
  expectations="$expectations --expectations art/tools/libcore_failures_concurrent_collector.txt"
fi

emulator="no"
if [ "$ANDROID_SERIAL" = "emulator-5554" ]; then
  emulator="yes"
fi

# Use JIT compiling by default.
use_jit=true

# Packages that currently work correctly with the expectation files.
working_packages=("dalvik.system"
                  "libcore.icu"
                  "libcore.io"
                  "libcore.java.lang"
                  "libcore.java.math"
                  "libcore.java.text"
                  "libcore.java.util"
                  "libcore.javax.crypto"
                  "libcore.javax.security"
                  "libcore.javax.sql"
                  "libcore.javax.xml"
                  "libcore.net"
                  "libcore.reflect"
                  "libcore.util"
                  "org.apache.harmony.annotation"
                  "org.apache.harmony.crypto"
                  "org.apache.harmony.luni"
                  "org.apache.harmony.nio"
                  "org.apache.harmony.regex"
                  "org.apache.harmony.testframework"
                  "org.apache.harmony.tests.java.io"
                  "org.apache.harmony.tests.java.lang"
                  "org.apache.harmony.tests.java.math"
                  "org.apache.harmony.tests.java.util"
                  "org.apache.harmony.tests.java.text"
                  "org.apache.harmony.tests.javax.security"
                  "tests.java.lang.String"
                  "jsr166")

# List of packages we could run, but don't have rights to revert
# changes in case of failures.
# "org.apache.harmony.security"

vogar_args=$@
while true; do
  if [[ "$1" == "--mode=device" ]]; then
    vogar_args="$vogar_args --device-dir=/data/local/tmp"
    vogar_args="$vogar_args --vm-command=/data/local/tmp/system/bin/art"
    vogar_args="$vogar_args --vm-arg -Ximage:/data/art-test/core-optimizing.art"
    shift
  elif [[ "$1" == "--mode=host" ]]; then
    # We explicitly give a wrong path for the image, to ensure vogar
    # will create a boot image with the default compiler. Note that
    # giving an existing image on host does not work because of
    # classpath/resources differences when compiling the boot image.
    vogar_args="$vogar_args --vm-arg -Ximage:/non/existent/vogar.art"
    shift
  elif [[ "$1" == "--no-jit" ]]; then
    # Remove the --no-jit from the arguments.
    vogar_args=${vogar_args/$1}
    use_jit=false
    shift
  elif [[ "$1" == "--debug" ]]; then
    # Remove the --debug from the arguments.
    vogar_args=${vogar_args/$1}
    vogar_args="$vogar_args --vm-arg -XXlib:libartd.so"
    shift
  elif [[ "$1" == "" ]]; then
    break
  else
    shift
  fi
done

# Increase the timeout, as vogar cannot set individual test
# timeout when being asked to run packages, and some tests go above
# the default timeout.
vogar_args="$vogar_args --timeout 480"

# Use Jack with "1.8" configuration.
vogar_args="$vogar_args --toolchain jack --language JN"

# JIT settings.
if $use_jit; then
  vogar_args="$vogar_args --vm-arg -Xcompiler-option --vm-arg --compiler-filter=interpret-only"
fi
vogar_args="$vogar_args --vm-arg -Xusejit:$use_jit"

# Run the tests using vogar.
echo "Running tests for the following test packages:"
echo ${working_packages[@]} | tr " " "\n"
vogar $vogar_args $expectations $(cparg $DEPS) ${working_packages[@]}
