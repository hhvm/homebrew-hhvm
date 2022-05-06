#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

class Hhvm4128 < Formula
  desc "JIT compiler and runtime for the Hack language"
  homepage "http://hhvm.com/"
  head "https://github.com/facebook/hhvm.git"
  url "https://dl.hhvm.com/source/hhvm-4.128.4.tar.gz"
  sha256 "914708be4e6f1f9fd2490cce598b9d5f07ca5a95730e707b4486cdf5ed82a3ce"

  bottle do
    root_url "https://dl.hhvm.com/homebrew-bottles"
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
  depends_on "dwarfutils"
  depends_on "gawk" => :build
  depends_on "libelf" => :build
  depends_on "libtool" => :build
  depends_on "md5sha1sum" => :build
  depends_on "pkg-config" => :build
  depends_on "re2c" => :build
  depends_on "wget" => :build

  # We statically link against icu4c as every non-bugfix release is not
  # backwards compatible; needing to rebuild for every release is too
  # brittle
  depends_on "icu4c" => :build
  depends_on "boost"
  depends_on "double-conversion"
  depends_on "freetype"
  depends_on "fribidi"
  depends_on "gd"
  depends_on "gettext"
  depends_on "glog"
  depends_on "gmp"
  depends_on "imagemagick@6"
  depends_on "jemalloc"
  depends_on "jpeg"
  depends_on "krb5"
  depends_on "libevent"
  depends_on "libmemcached"
  depends_on "libsodium"
  depends_on "libpng"
  depends_on "libxml2"
  depends_on "libzip"
  depends_on "lz4"
  depends_on "mcrypt"
  depends_on "oniguruma"
  depends_on "openssl@1.1"
  depends_on "pcre" # Used for Hack but not HHVM build - see #116
  depends_on "postgresql"
  depends_on "sqlite"
  depends_on "tbb@2020"
  depends_on "zstd"

  def install
    cmake_args = std_cmake_args + %W[
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
