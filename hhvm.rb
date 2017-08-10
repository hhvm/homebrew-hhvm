class Hhvm < Formula
  desc "JIT compiler and runtime for the PHP and Hack languages"
  homepage "http://hhvm.com/"
  url "http://dl.hhvm.com/source/hhvm-3.21.0.tar.bz2"
  sha256 "702a47053b88f499514edf88e71b409abbcc0d77ce01799d76d2adf5bac07478"
  revision 0

  head "https://github.com/facebook/hhvm.git"

  bottle do
    root_url "https://github.com/PranayAgarwal/homebrew-hhvm/releases/download/v3.21.0"
    sha256 "6ff0f9b6ba19a82a6a60809c53917d1077f4c7fcb72a4d1d8bfbf49f5c137354" => :sierra
  end

  option "with-debug", <<-EOS.undent
    Make an unoptimized build with assertions enabled. This will run PHP and
    Hack code dramatically slower than a release build, and is suitable mostly
    for debugging HHVM itself.
  EOS

  # Needs libdispatch APIs only available in Mavericks and newer.
  depends_on :macos => :mavericks

  # We need to build with upstream clang -- the version Apple ships doesn't
  # support TLS, which HHVM uses heavily. (And gcc compiles HHVM fine, but
  # causes ld to trip an assert and fail, for unclear reasons.)
  depends_on "llvm" => :build

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "dwarfutils" => :build
  depends_on "gawk" => :build
  depends_on "libelf" => :build
  depends_on "libtool" => :build
  depends_on "md5sha1sum" => :build
  depends_on "ocaml" => :build
  depends_on "ocamlbuild" => :build
  depends_on "pkg-config" => :build

  # Folly is currently incompatible with boost >1.6.0 due to changes in the
  # fibers api
  depends_on "boost"

  depends_on "freetype"
  depends_on "gd"
  depends_on "gettext"
  depends_on "glog"
  depends_on "gmp"
  depends_on "icu4c"
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
  depends_on "pcre"
  depends_on "readline"
  depends_on "sqlite"
  depends_on "tbb"

  def install
    # Fix for 'dyld: lazy symbol binding failed: Symbol not found: _clock_gettime' issue
    if MacOS.version == "10.11" && MacOS::Xcode.installed? && MacOS::Xcode.version >= "8.0"
        inreplace "third-party/webscalesqlclient/mysql-5.6/config.h.cmake", "#cmakedefine HAVE_CLOCK_GETTIME 1", ""
        ENV["ac_cv_search_clock_gettime"] = "no"
        ENV["ac_have_clock_syscall"] = "no"
    end

    if MacOS.version == "10.10"
      inreplace "third-party/folly/src/folly/detail/SocketFastOpen.h" do |s|
        s.gsub! "#define FOLLY_ALLOW_TFO 1",
                "#define FOLLY_ALLOW_TFO 0"
      end
    end

    # Work around https://github.com/Homebrew/homebrew/issues/42957 by making
    # brew's superenv forget which libraries it wants to inject into ld
    # invocations. (We tell cmake below where they all are, so we don't need
    # them to be injected like that.)
    ENV["HOMEBREW_LIBRARY_PATHS"] = ""

    cmake_args = %W[
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DDEFAULT_CONFIG_DIR=#{etc}/hhvm
    ]

    # Must use upstream clang -- see above.
    cmake_args += %W[
      -DCMAKE_CXX_COMPILER=#{Formula["llvm"].opt_bin}/clang++
      -DCMAKE_C_COMPILER=#{Formula["llvm"].opt_bin}/clang
      -DCMAKE_ASM_COMPILER=#{Formula["llvm"].opt_bin}/clang
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

    # We tell HHVM below where readline is, but due to the machinery of CMake's
    # subprojects, it's hard for HHVM to tell one of its subproject dependencies
    # where readline is, so be more aggressive in a way that makes it through.
    cmake_args << "-DCMAKE_C_FLAGS=-I#{Formula["readline"].opt_include} -L#{Formula["readline"].opt_lib} -I#{Formula["libsodium"].opt_include} -L#{Formula["libsodium"].opt_lib}"
    cmake_args << "-DCMAKE_CXX_FLAGS=-I#{Formula["readline"].opt_include} -L#{Formula["readline"].opt_lib} -I#{Formula["libsodium"].opt_include} -L#{Formula["libsodium"].opt_lib}"

    # Dependency information.
    cmake_args += %W[
      -DAWK_EXECUTABLE=#{Formula["gawk"].opt_bin}/gawk
      -DBoost_INCLUDE_DIR=#{Formula["boost"].opt_include}
      -DBoost_LIBRARY_DIR=#{Formula["boost"].opt_lib}
      -DLIBMAGICKWAND_INCLUDE_DIRS=#{Formula["imagemagick@6"].opt_include}/ImageMagick-6
      -DLIBMAGICKWAND_LIBRARIES=#{Formula["imagemagick@6"].opt_lib}/libMagickWand-6.Q16.dylib
      -DLIBMAGICKCORE_LIBRARIES=#{Formula["imagemagick@6"].opt_lib}/libMagickCore-6.Q16.dylib
      -DFREETYPE_INCLUDE_DIRS=#{Formula["freetype"].opt_include}/freetype2
      -DFREETYPE_LIBRARIES=#{Formula["freetype"].opt_lib}/libfreetype.dylib
      -DGMP_INCLUDE_DIR=#{Formula["gmp"].opt_include}
      -DGMP_LIBRARY=#{Formula["gmp"].opt_lib}/libgmp.dylib
      -DICU_INCLUDE_DIR=#{Formula["icu4c"].opt_include}
      -DICU_I18N_LIBRARY=#{Formula["icu4c"].opt_lib}/libicui18n.dylib
      -DICU_LIBRARY=#{Formula["icu4c"].opt_lib}/libicuuc.dylib
      -DICU_DATA_LIBRARY=#{Formula["icu4c"].opt_lib}/libicudata.dylib
      -DJEMALLOC_INCLUDE_DIR=#{Formula["jemalloc"].opt_include}
      -DJEMALLOC_LIB=#{Formula["jemalloc"].opt_lib}/libjemalloc.dylib
      -DLIBDWARF_INCLUDE_DIRS=#{Formula["dwarfutils"].opt_include}
      -DLIBDWARF_LIBRARIES=#{Formula["dwarfutils"].opt_lib}/libdwarf.a
      -DLIBELF_INCLUDE_DIRS=#{Formula["libelf"].opt_include}/libelf
      -DLIBELF_LIBRARIES=#{Formula["libelf"].opt_lib}/libelf.a
      -DLIBEVENT_INCLUDE_DIR=#{Formula["libevent"].opt_include}
      -DLIBEVENT_LIB=#{Formula["libevent"].opt_lib}/libevent.dylib
      -DLIBGLOG_INCLUDE_DIR=#{Formula["glog"].opt_include}
      -DLIBGLOG_LIBRARY=#{Formula["glog"].opt_lib}/libglog.dylib
      -DLIBINTL_INCLUDE_DIR=#{Formula["gettext"].opt_include}
      -DLIBINTL_LIBRARIES=#{Formula["gettext"].opt_lib}/libintl.dylib
      -DLIBJPEG_INCLUDE_DIRS=#{Formula["jpeg"].opt_include}
      -DLIBJPEG_LIBRARIES=#{Formula["jpeg"].opt_lib}/libjpeg.dylib
      -DLIBMEMCACHED_INCLUDE_DIR=#{Formula["libmemcached"].opt_include}
      -DLIBMEMCACHED_LIBRARY=#{Formula["libmemcached"].opt_lib}/libmemcached.dylib
      -DLIBPNG_INCLUDE_DIRS=#{Formula["libpng"].opt_include}
      -DLIBPNG_LIBRARIES=#{Formula["libpng"].opt_lib}/libpng.dylib
      -DLIBSQLITE3_INCLUDE_DIR=#{Formula["sqlite"].opt_include}
      -DLIBSQLITE3_LIBRARY=#{Formula["sqlite"].opt_lib}/libsqlite3.dylib
      -DMcrypt_INCLUDE_DIR=#{Formula["mcrypt"].opt_include}
      -DMcrypt_LIB=#{Formula["mcrypt"].opt_lib}/libmcrypt.dylib
      -DPC_SQLITE3_FOUND=1
      -DLIBXML2_INCLUDE_DIR=#{Formula["libxml2"].opt_include}/libxml2
      -DLIBXML2_LIBRARIES=#{Formula["libxml2"].opt_lib}/libxml2.dylib
      -DLIBZIP_INCLUDE_DIR_ZIP=#{Formula["libzip"].opt_include}
      -DLIBZIP_INCLUDE_DIR_ZIPCONF=#{Formula["libzip"].opt_lib}/libzip/include
      -DLIBZIP_LIBRARY=#{Formula["libzip"].opt_lib}/libzip.dylib
      -DLZ4_INCLUDE_DIR=#{Formula["lz4"].opt_include}
      -DLZ4_LIBRARY=#{Formula["lz4"].opt_lib}/liblz4.dylib
      -DOCAML=#{Formula["ocaml"].opt_bin}/ocaml
      -DOCAMLC=#{Formula["ocaml"].opt_bin}/ocamlc.opt
      -DOCAMLOPT=#{Formula["ocaml"].opt_bin}/ocamlopt.opt
      -DOCAMLBUILD=#{Formula["ocamlbuild"].opt_bin}/ocamlbuild
      -DONIGURUMA_INCLUDE_DIR=#{Formula["oniguruma"].opt_include}
      -DONIGURUMA_LIBRARY=#{Formula["oniguruma"].opt_lib}/libonig.dylib
      -DOPENSSL_INCLUDE_DIR=#{Formula["openssl"].opt_include}
      -DOPENSSL_CRYPTO_LIBRARY=#{Formula["openssl"].opt_lib}/libcrypto.dylib
      -DCRYPT_LIB=#{Formula["openssl"].opt_lib}/libcrypto.dylib
      -DOPENSSL_SSL_LIBRARY=#{Formula["openssl"].opt_lib}/libssl.dylib
      -DPCRE_INCLUDE_DIR=#{Formula["pcre"].opt_include}
      -DPCRE_LIBRARY=#{Formula["pcre"].opt_lib}/libpcre.dylib
      -DPKG_CONFIG_EXECUTABLE=#{Formula["pkg-config"].opt_bin}/pkg-config
      -DREADLINE_INCLUDE_DIR=#{Formula["readline"].opt_include}
      -DREADLINE_LIBRARY=#{Formula["readline"].opt_lib}/libreadline.dylib
      -DTBB_INCLUDE_DIR=#{Formula["tbb"].opt_include}
      -DTBB_INSTALL_DIR=#{Formula["tbb"].opt_prefix}
      -DTBB_LIBRARY=#{Formula["tbb"].opt_lib}/libtbb.dylib
      -DTBB_LIBRARY_DEBUG=#{Formula["tbb"].opt_lib}/libtbb.dylib
      -DTBB_LIBRARY_DIR=#{Formula["tbb"].opt_lib}
      -DTBB_MALLOC_LIBRARY=#{Formula["tbb"].opt_lib}/libtbbmalloc.dylib
      -DTBB_MALLOC_LIBRARY_DEBUG=#{Formula["tbb"].opt_lib}/libtbbmalloc.dylib
      -DLIBSODIUM_INCLUDE_DIRS=#{Formula["libsodium"].opt_include}
      -DLIBSODIUM_LIBRARIES=#{Formula["libsodium"].opt_lib}/libsodium.dylib
    ]

    # brew's PCRE always has the JIT enabled; work around issue where the CMake
    # scripts will pick up the wrong PCRE and think it is disabled.
    cmake_args << "-DSYSTEM_PCRE_HAS_JIT=1"

    # Debug builds. This switch is all that's needed, it sets all the right
    # cflags and other config changes.
    cmake_args << "-DCMAKE_BUILD_TYPE=Debug" if build.with? "debug"

    # TBB looks for itself in a different place than brew installs to.
    ENV["TBB_ARCH_PLATFORM"] = "."

    # CMake loves to pick up things automagically out of directories it
    # shouldn't, e.g., from a MacPorts installation in /opt/local. Force it to
    # read only from the explicit dependency information we give it.
    # Unfortunately this means we have to also explicitly specify stuff in /usr
    # that's a core part of OS X that would normally also be picked up
    # automatically.
    cmake_args += %W[
      -DCMAKE_FIND_ROOT_PATH=/tmp
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=ONLY
      -DCMAKE_SYSTEM_NAME=Darwin
      -DCMAKE_CROSSCOMPILING=0
      -DCMAKE_AR=/usr/bin/ar
      -DCMAKE_RANLIB=/usr/bin/ranlib
      -DBZIP2_INCLUDE_DIR=/usr/include
      -DBZIP2_LIBRARIES=/usr/lib/libbz2.dylib
      -DCURL_INCLUDE_DIR=/usr/include
      -DCURL_LIBRARY=/usr/lib/libcurl.dylib
      -DDL_LIB=/usr/lib/libdl.dylib
      -DEXPAT_INCLUDE_DIR=/usr/include
      -DEXPAT_LIBRARY=/usr/lib/libexpat.dylib
      -DGPERF_EXECUTABLE=/usr/bin/gperf
      -DKERBEROS_LIB=/usr/lib/libgssapi_krb5.dylib
      -DLBER_LIBRARIES=/usr/lib/liblber.dylib
      -DLDAP_INCLUDE_DIR=/usr/include
      -DLDAP_LIBRARIES=/usr/lib/libldap.dylib
      -DLIBDL_INCLUDE_DIRS=/usr/include
      -DLIBDL_LIBRARIES=/usr/lib/libdl.dylib
      -DLIBICONV_INCLUDE_DIR=/usr/include
      -DLIBICONV_LIBRARY=/usr/lib/libiconv.dylib
      -DLIBPTHREAD_INCLUDE_DIRS=/usr/include
      -DLIBPTHREAD_LIBRARIES=/usr/lib/libpthread.dylib
      -DLIBXSLT_EXSLT_LIBRARY=/usr/lib/libexslt.dylib
      -DLIBXSLT_INCLUDE_DIR=/usr/include
      -DLIBXSLT_LIBRARIES=/usr/lib/libxslt.dylib
      -DRESOLV_LIB=/usr/lib/libresolv.dylib
      -DZLIB_INCLUDE_DIR=/usr/include
      -DZLIB_LIBRARY=/usr/lib/libz.dylib
    ]

    system "cmake", *cmake_args
    system "make"
    system "make", "install"
  end

  def post_install
    ini = etc/"hhvm"
    (ini/"php.ini").write php_ini unless File.exist? (ini/"php.ini")
    (ini/"server.ini").write server_ini unless File.exist? (ini/"server.ini")
  end

  test do
    (testpath/"test.php").write <<-EOS.undent
      <?php
      exit(is_integer(HHVM_VERSION_ID) ? 0 : 1);
    EOS
    system "#{bin}/hhvm", testpath/"test.php"
  end

  plist_options :manual => "hhvm -m daemon -c #{HOMEBREW_PREFIX}/etc/hhvm/php.ini -c #{HOMEBREW_PREFIX}/etc/hhvm/server.ini"

  def plist
    <<-EOS.undent
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
    <<-EOS.undent
      ; php options
      session.save_handler = files
      session.save_path = #{var}/lib/hhvm/sessions
      session.gc_maxlifetime = 1440

      ; hhvm specific
      hhvm.log.level = Warning
      hhvm.log.always_log_unhandled_exceptions = true
      hhvm.log.runtime_error_reporting_level = 8191
      hhvm.mysql.typed_results = false
    EOS
  end

  # https://github.com/hhvm/packaging/blob/master/hhvm/deb/skeleton/etc/hhvm/server.ini
  def server_ini
    <<-EOS.undent
      ; php options

      pid = #{var}/run/hhvm/pid

      ; hhvm specific

      hhvm.server.port = 9000
      hhvm.server.type = fastcgi
      hhvm.server.default_document = index.php
      hhvm.log.use_log_file = true
      hhvm.log.file = #{var}/log/hhvm/error.log
      hhvm.repo.central.path = #{var}/run/hhvm/hhvm.hhbc
    EOS
  end
end
