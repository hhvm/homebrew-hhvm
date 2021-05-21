#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Homebrew doesn't support specifying anything more recent than 'nehalem',
# but nehalem is 19x slower than sandybrdige at some real-world workloads,
# and sandybridge is an old enough architecture that we're going to assume
# that HHVM users have it.
module MonkeyPatchCPU
  def optimization_flags
    super.merge({nehalem: "-march=sandybridge"}).freeze
  end
end

class << Hardware::CPU
  prepend MonkeyPatchCPU
end

class Hhvm449 < Formula
  desc "JIT compiler and runtime for the Hack language"
  homepage "http://hhvm.com/"
  head "https://github.com/facebook/hhvm.git"
  url "https://dl.hhvm.com/source/hhvm-4.49.1.tar.gz"
  sha256 "3c58dd2983de6f33df189cf9dd75172e2a8c81cdb588bda0a5f7ef1ded4e56c6"
  patch :DATA

  bottle do
    root_url "https://dl.hhvm.com/homebrew-bottles"
    sha256 catalina: "e178d458df28fddc0aec578001f87d34be8ff437d413c9c0ab5c806d380e9c1f"
    sha256 mojave: "41fea57cac42960c91d3b8b8b928a9db77bbe9ab9c929c7f93506e11531d5d1f"
  end

  option "with-debug", <<~EOS
    Make an unoptimized build with assertions enabled. This will run PHP and
    Hack code dramatically slower than a release build, and is suitable mostly
    for debugging HHVM itself.
  EOS

  # Needs very recent xcode
  depends_on :macos => :sierra

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "double-conversion"
  depends_on "dwarfutils" => :build
  depends_on "gawk" => :build
  depends_on "libelf" => :build
  depends_on "libtool" => :build
  depends_on "md5sha1sum" => :build
  depends_on "pkg-config" => :build
  depends_on "wget" => :build

  # We statically link against icu4c as every non-bugfix release is not
  # backwards compatible; needing to rebuild for every release is too
  # brittle
  depends_on "icu4c" => :build
  depends_on "boost"
  depends_on "freetype"
  depends_on "gd"
  depends_on "gettext"
  depends_on "glog"
  depends_on "gmp"
  depends_on "imagemagick@6"
  depends_on "jemalloc"
  depends_on "jpeg"
  depends_on "libevent"
  depends_on "libmemcached"
  depends_on "libsodium"
  depends_on "libpng"
  depends_on "libxml2"
  depends_on "libzip"
  depends_on "lz4"
  depends_on "mcrypt"
  depends_on "oniguruma"
  depends_on "openssl"
  depends_on "pcre" # Used for Hack but not HHVM build - see #116
  depends_on "postgresql"
  depends_on "sqlite"
  depends_on "tbb@2020"

  def install
    cmake_args = std_cmake_args + %W[
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_INSTALL_SYSCONFDIR=#{etc}
      -DDEFAULT_CONFIG_DIR=#{etc}/hhvm
    ]

    # Force use of bundled PCRE to workaround #116
    cmake_args += %W[
      -DSYSTEM_PCRE_HAS_JIT=0
    ]

    # Features which don't work on OS X yet since they haven't been ported yet.
    cmake_args += %W[
      -DENABLE_MCROUTER=OFF
      -DENABLE_EXTENSION_MCROUTER=OFF
      -DENABLE_EXTENSION_IMAP=OFF
    ]

    # Required to specify a socket path if you are using the bundled async SQL
    # client (which is very strongly recommended).
    cmake_args << "-DMYSQL_UNIX_SOCK_ADDR=/tmp/mysql.sock"

    # LZ4 warning macros are currently incompatible with clang
    cmake_args << "-DCMAKE_C_FLAGS=-DLZ4_DISABLE_DEPRECATE_WARNINGS=1"
    cmake_args << "-DCMAKE_CXX_FLAGS=-DLZ4_DISABLE_DEPRECATE_WARNINGS=1 -DU_USING_ICU_NAMESPACE=1"

    # Debug builds. This switch is all that's needed, it sets all the right
    # cflags and other config changes.
    if build.with? "debug"
      cmake_args << "-DCMAKE_BUILD_TYPE=Debug"
    else
      cmake_args << "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
    end

    # Statically link libICU
    cmake_args += %W[
      -DICU_INCLUDE_DIR=#{Formula["icu4c"].opt_include}
      -DICU_I18N_LIBRARY=#{Formula["icu4c"].opt_lib}/libicui18n.a
      -DICU_LIBRARY=#{Formula["icu4c"].opt_lib}/libicuuc.a
      -DICU_DATA_LIBRARY=#{Formula["icu4c"].opt_lib}/libicudata.a
    ]

    # TBB looks for itself in a different place than brew installs to.
    ENV["TBB_ARCH_PLATFORM"] = "."
    cmake_args += %W[
      -DTBB_INCLUDE_DIR=#{Formula["tbb@2020"].opt_include}
      -DTBB_INSTALL_DIR=#{Formula["tbb@2020"].opt_prefix}
      -DTBB_LIBRARY=#{Formula["tbb@2020"].opt_lib}/libtbb.dylib
      -DTBB_LIBRARY_DEBUG=#{Formula["tbb@2020"].opt_lib}/libtbb.dylib
      -DTBB_LIBRARY_DIR=#{Formula["tbb@2020"].opt_lib}
      -DTBB_MALLOC_LIBRARY=#{Formula["tbb@2020"].opt_lib}/libtbbmalloc.dylib
      -DTBB_MALLOC_LIBRARY_DEBUG=#{Formula["tbb@2020"].opt_lib}/libtbbmalloc.dylib
    ]

    system "cmake", *cmake_args, '.'
    system "make"
    system "make", "install"

    tp_notices = (share/"doc/third_party_notices.txt")
    (share/"doc").install "third-party/third_party_notices.txt"
    (share/"doc/third_party_notices.txt").append_lines <<EOF

-----

The following software may be included in this product: icu4c. This Software contains the following license and notice below:

Unicode Data Files include all data files under the directories
http://www.unicode.org/Public/, http://www.unicode.org/reports/,
http://www.unicode.org/cldr/data/, http://source.icu-project.org/repos/icu/, and
http://www.unicode.org/utility/trac/browser/.

Unicode Data Files do not include PDF online code charts under the
directory http://www.unicode.org/Public/.

Software includes any source code published in the Unicode Standard
or under the directories
http://www.unicode.org/Public/, http://www.unicode.org/reports/,
http://www.unicode.org/cldr/data/, http://source.icu-project.org/repos/icu/, and
http://www.unicode.org/utility/trac/browser/.

NOTICE TO USER: Carefully read the following legal agreement.
BY DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING UNICODE INC.'S
DATA FILES ("DATA FILES"), AND/OR SOFTWARE ("SOFTWARE"),
YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
TERMS AND CONDITIONS OF THIS AGREEMENT.
IF YOU DO NOT AGREE, DO NOT DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE
THE DATA FILES OR SOFTWARE.

COPYRIGHT AND PERMISSION NOTICE

Copyright © 1991-2017 Unicode, Inc. All rights reserved.
Distributed under the Terms of Use in http://www.unicode.org/copyright.html.

Permission is hereby granted, free of charge, to any person obtaining
a copy of the Unicode data files and any associated documentation
(the "Data Files") or Unicode software and any associated documentation
(the "Software") to deal in the Data Files or Software
without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, and/or sell copies of
the Data Files or Software, and to permit persons to whom the Data Files
or Software are furnished to do so, provided that either
(a) this copyright and permission notice appear with all copies
of the Data Files or Software, or
(b) this copyright and permission notice appear in associated
Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT OF THIRD PARTY RIGHTS.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS
NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL
DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder
shall not be used in advertising or otherwise to promote the sale,
use or other dealings in these Data Files or Software without prior
written authorization of the copyright holder.
EOF

    ini = etc/"hhvm"
    (ini/"php.ini").write php_ini unless File.exist? (ini/"php.ini")
    (ini/"server.ini").write server_ini unless File.exist? (ini/"server.ini")
  end

  test do
    (testpath/"test.php").write <<~EOS
      <?php
      exit(is_integer(HHVM_VERSION_ID) ? 0 : 1);
    EOS
    system "#{bin}/hhvm", testpath/"test.php"
  end

  plist_options :manual => "hhvm -m daemon -c #{HOMEBREW_PREFIX}/etc/hhvm/php.ini -c #{HOMEBREW_PREFIX}/etc/hhvm/server.ini"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>ProgramArguments</key>
          <array>
              <string>#{opt_bin}/hhvm</string>
              <string>-m</string>
              <string>server</string>
              <string>-c</string>
              <string>#{etc}/hhvm/php.ini</string>
              <string>-c</string>
              <string>#{etc}/hhvm/server.ini</string>
          </array>
          <key>WorkingDirectory</key>
          <string>#{HOMEBREW_PREFIX}</string>
        </dict>
      </plist>
    EOS
  end

  # https://github.com/hhvm/packaging/blob/master/hhvm/deb/skeleton/etc/hhvm/php.ini
  def php_ini
    <<~EOS
      ; php options
      session.save_handler = files
      session.save_path = #{var}/lib/hhvm/sessions
      session.gc_maxlifetime = 1440

      ; hhvm specific
      hhvm.log.always_log_unhandled_exceptions = true
      hhvm.log.runtime_error_reporting_level = 8191
      hhvm.mysql.typed_results = false
    EOS
  end

  # https://github.com/hhvm/packaging/blob/master/hhvm/deb/skeleton/etc/hhvm/server.ini
  def server_ini
    <<~EOS
      ; php options

      pid = #{var}/run/hhvm/pid

      ; hhvm specific

      hhvm.server.port = 9000
      hhvm.server.default_document = index.php
      hhvm.log.use_log_file = true
      hhvm.log.file = #{var}/log/hhvm/error.log
      hhvm.repo.central.path = #{var}/run/hhvm/hhvm.hhbc
    EOS
  end
end

__END__
diff --git a/CMake/HPHPFindLibs.cmake b/CMake/HPHPFindLibs.cmake
index 46c12fa43f..13f77b627e 100644
--- a/CMake/HPHPFindLibs.cmake
+++ b/CMake/HPHPFindLibs.cmake
@@ -258,13 +258,6 @@ SET(CMAKE_REQUIRED_LIBRARIES)
 find_package(ZLIB REQUIRED)
 include_directories(${ZLIB_INCLUDE_DIR})

-# oniguruma
-find_package(ONIGURUMA REQUIRED)
-include_directories(${ONIGURUMA_INCLUDE_DIRS})
-if (ONIGURUMA_STATIC)
-  add_definitions("-DONIG_EXTERN=extern")
-endif()
-
 # libpthreads
 find_package(PThread REQUIRED)
 include_directories(${LIBPTHREAD_INCLUDE_DIRS})
@@ -362,30 +355,19 @@ endif()
 include_directories(${HPHP_HOME}/hphp)

 macro(hphp_link target)
-  # oniguruma must remain first for OS X to work -- see below for a somewhat
-  # dogscience explanation. If you deeply understand this, feel free to fix
-  # properly; in particular, two-level namespaces on OS X should allow us to
-  # say *which* copy of the disputed functions we want, but I don' t know
-  # how to get that to work.
-  #
-  # oniguruma has some of its own implementations of POSIX regex functions,
-  # like regcomp() an regexec(). We use onig everywhere, for both its own
-  # sepcial functions and for the POSIX replacements. This means that the
-  # linker needs to pick the implementions of the POSIX regex functions from
-  # onig, not libc.
+  # oniguruma must be linked first for MacOS's linker to do the right thing -
+  # that's handled in HPHPSetup.cmake
   #
-  # On Linux, that works out fine, since the linker sees onig on the link
-  # line before (implicitly) libc. However, on OS X, despide the manpage for
-  # ld claiming otherwise about indirect dylib dependencies, as soon as we
-  # include one of the libs here that pull in libSystem.B, the linker will
-  # pick the implementations of those functions from libc, not from onig.
-  # And since we've included the onig headers, which have very slightly
-  # different definintions for some of the key data structures, things go
-  # quite awry -- this manifests as infinite loops or crashes when calling
-  # the PHP split() function.
-  #
-  # So make sure to link onig first, so its implementations are picked.
-  target_link_libraries(${target} ${ONIGURUMA_LIBRARIES})
+  # That only handles linking - we still need to make sure that:
+  # - oniguruma is built first, if needed (so we have the header files)
+  # - we build with the header files in the include path
+  if(APPLE)
+    add_dependencies(${target} onig)
+    target_include_directories(${target} PRIVATE $<TARGET_PROPERTY:onig,INTERFACE_INCLUDE_DIRECTORIES>)
+  else()
+    # Otherwise, the linker does the right thing, which sometimes means putting it after things that use it
+    target_link_libraries(${target} onig)
+  endif()

   if (LIBDL_LIBRARIES)
     target_link_libraries(${target} ${LIBDL_LIBRARIES})
diff --git a/CMake/HPHPSetup.cmake b/CMake/HPHPSetup.cmake
index 8ae726501d..f3480d6c02 100644
--- a/CMake/HPHPSetup.cmake
+++ b/CMake/HPHPSetup.cmake
@@ -9,7 +9,31 @@ set(HHVM_WHOLE_ARCHIVE_LIBRARIES

 set(HHVM_WRAP_SYMS)

+# Oniguruma ('onig') must be first:
+#
+# oniguruma has some of its own implementations of POSIX regex functions,
+# like regcomp() and regexec(). We use onig everywhere, for both its own
+# special functions and for the POSIX replacements. This means that the
+# linker needs to pick the implementions of the POSIX regex functions from
+# onig, not libc.
+#
+# On Linux, that works out fine, since the linker sees onig on the link
+# line before (implicitly) libc. However, on OS X, despite the manpage for
+# ld claiming otherwise about indirect dylib dependencies, as soon as we
+# include one of the libs here that pull in libSystem.B, the linker will
+# pick the implementations of those functions from libc, not from onig.
+# And since we've included the onig headers, which have very slightly
+# different definintions for some of the key data structures, things go
+# quite awry -- this manifests as infinite loops or crashes when calling
+# the PHP split() function.
+#
+# So make sure to link onig first, so its implementations are picked.
+#
+# Using the generator expression to explicitly pull the path in early, otherwise
+# it gets resolved later and put later in the build arguments, and makes
+# hphp/test/slow/ext_preg segfault.
 set(HHVM_LINK_LIBRARIES
+  $<TARGET_PROPERTY:onig,INTERFACE_LINK_LIBRARIES>
   ${HHVM_WRAP_SYMS}
   hphp_analysis
   hphp_system
diff --git a/hphp/CMakeLists.txt b/hphp/CMakeLists.txt
index e1251b5078..87f2ed78fd 100644
--- a/hphp/CMakeLists.txt
+++ b/hphp/CMakeLists.txt
@@ -82,8 +82,6 @@ if (ENABLE_COTIRE)
       "${ARCH_INCLUDE_PATH}"
       "${CCLIENT_INCLUDE_PATH}"
       "${JEMALLOC_INCLUDE_DIR}/jemalloc"
-      "${ONIGURUMA_INCLUDE_DIR}/onigposix.h"
-      "${ONIGURUMA_INCLUDE_DIR}/oniguruma.h"
       "${LIBPNG_INCLUDE_DIRS}/png.h"
       "${LDAP_INCLUDE_DIR}/ldap.h"
       "${LIBSQLITE3_INCLUDE_DIR}/sqlite3ext.h"
diff --git a/third-party/CMakeLists.txt b/third-party/CMakeLists.txt
index cab8d3b83c..8273d57e1d 100644
--- a/third-party/CMakeLists.txt
+++ b/third-party/CMakeLists.txt
@@ -14,6 +14,10 @@
 #   +----------------------------------------------------------------------+
 #

+# oniguruma/ is special: it is set up from HPHPFindLibs as it must be included
+# *first* to take precedence over libc regexp functions
+add_subdirectory(oniguruma)
+
 ##### --- header --- #####
 set(EXTRA_INCLUDE_PATHS)
 set(THIRD_PARTY_MODULES)
diff --git a/third-party/oniguruma/CMakeLists.txt b/third-party/oniguruma/CMakeLists.txt
new file mode 100644
index 0000000000..4dd7a7ab64
--- /dev/null
+++ b/third-party/oniguruma/CMakeLists.txt
@@ -0,0 +1,50 @@
+cmake_minimum_required(VERSION 2.8.0)
+include(ExternalProject)
+
+set(ONIG_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/onig-prefix")
+ExternalProject_add(
+  onigBuild
+  URL "https://github.com/kkos/oniguruma/releases/download/v6.9.5/onig-6.9.5.tar.gz"
+  URL_HASH SHA512=2bdb24914e7069c6df9ab8a3d0190ddb58440d94b13860cdc36d259062ae0bc2aa85d564a4209ec596fc7ee47b0823d1b817d4f7ffcc3ea60e9870da84491dc1
+  PREFIX "${ONIG_PREFIX}"
+  CONFIGURE_COMMAND
+  "${ONIG_PREFIX}/src/onigBuild/configure"
+    "--prefix=${ONIG_PREFIX}"
+    --enable-posix-api=yes
+    # Oniguruma requires absolute paths for these. This is a bit unusual.
+    "--libdir=${ONIG_PREFIX}/lib"
+    "--includedir=${ONIG_PREFIX}/include"
+    --disable-dependency-tracking
+    --disable-shared
+    --enable-static
+)
+
+add_library(onig INTERFACE)
+
+find_package(ONIGURUMA)
+set(CMAKE_REQUIRED_INCLUDES ${ONIGURUMA_INCLUDE_DIRS})
+CHECK_CXX_SOURCE_COMPILES(
+"#include <onigposix.h>
+int main() {
+  return 0;
+}"
+  HAVE_ONIGPOSIX_H
+)
+set(CMAKE_REQUIRED_INCLUDES)
+
+if(HAVE_ONIGPOSIX_H)
+  message(STATUS "Using system oniguruma")
+  target_link_libraries(onig INTERFACE ${ONIGURUMA_LIBRARIES})
+  target_include_directories(onig INTERFACE ${ONIGURUMA_INCLUDE_DIRS})
+  if (ONIGURUMA_STATIC)
+    target_compile_definitions(onig INTERFACE "-DONIG_EXTERN=extern")
+  endif()
+else()
+  message(STATUS "Building oniguruma from third-party/")
+  add_dependencies(onig onigBuild)
+  target_include_directories(onig INTERFACE "${ONIG_PREFIX}/include")
+  target_link_libraries(onig INTERFACE
+    "${ONIG_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}onig${CMAKE_STATIC_LIBRARY_SUFFIX}"
+  )
+  target_compile_definitions(onig INTERFACE "-DONIG_EXTERN=extern")
+endif()
