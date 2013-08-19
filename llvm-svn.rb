require 'formula'

class Clang < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/clang.git'
end

class ClangToolsExtra < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/clang-tools-extra.git'
end

class CompilerRt < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/compiler-rt.git'
end

class Libcxx < Formula
  homepage  'http://llvm.org'
  head 'http://llvm.org/git/libcxx.git'
end

class LlvmSvn < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/llvm.git'

  option :universal
  option 'with-libcxx', 'Build libc++ standard library support'
  option 'with-clang', 'Build Clang C/ObjC/C++ frontend'
  option 'with-clang-tools-extra', 'Build Clang Tools Extra'
  option 'with-asan', 'Include support for -faddress-sanitizer (from compiler-rt)'
  option 'disable-shared', "Don't build LLVM as a shared library"
  option 'all-targets', 'Build all target backends'
  option 'rtti', 'Build with C++ RTTI'
  option 'disable-assertions', 'Speeds up LLVM, but provides less debug information'

  depends_on :python => :recommended

  env :std if build.universal?

  def install
    if build.with? 'python' and build.include? 'disable-shared'
      raise 'The Python bindings need the shared library.'
    end

    Clang.new('clang').brew do
      (buildpath/'tools/clang').install Dir['*']
    end if build.include? 'with-clang'

    ClangToolsExtra.new('clang-tools-extra').brew do
      (buildpath/'tools/clang/tools/extra').install Dir['*']
    end if build.include?('with-clang') && build.include?('with-clang-tools-extra')

    CompilerRt.new("compiler-rt").brew do
      (buildpath/'projects/compiler-rt').install Dir['*']
    end if build.include? 'with-asan'

    Libcxx.new('libcxx').brew do
      (buildpath/'projects/libcxx').install Dir['*']
    end if build.include? 'with-libcxx'

    if build.universal?
      ENV['UNIVERSAL'] = '1'
      ENV['UNIVERSAL_ARCH'] = 'i386 x86_64'
    end

    ENV['REQUIRES_RTTI'] = '1' if build.include? 'rtti'

    install_prefix = lib/"llvm-#{version}"

    args = [
      "--prefix=#{install_prefix}",
      "--enable-optimized",
      # As of LLVM 3.1, attempting to build ocaml bindings with Homebrew's
      # OCaml 3.12.1 results in errors.
      "--disable-bindings",
    ]

    args << '--enable-libcpp' if build.include? 'with-libcxx'

    if build.include? 'all-targets'
      args << '--enable-targets=all'
    else
      args << '--enable-targets=host'
    end
    args << "--enable-shared" unless build.include? 'disable-shared'

    args << "--disable-assertions" if build.include? 'disable-assertions'

    system './configure', *args
    system 'make', 'VERBOSE=1'
    puts "before installing llvm [rhysd]"
    system 'make', 'VERBOSE=1', 'install'

    suffix = `#{install_prefix}/bin/clang --version`.split("\n").first.slice(/\d\.\d/)
    puts "******************** suffix is #{suffix} ********************** [rhysd]"

    # Putting libcxx in projects only ensures that headers are installed.
    # Manually "make install" to actually install the shared libs.
    cd buildpath/'projects/libcxx' do
      libcxx_make_args = [
        # The following flags are needed so it can be installed correctly.
        "DSTROOT=#{install_prefix}",
        "SYMROOT=#{buildpath}/projects/libcxx"
      ]
      puts "before installing libcxx [rhysd]"
      system 'make', 'install', *libcxx_make_args
    end if build.include? 'with-libcxx'

    if python
      # Install llvm python bindings.
      mv buildpath/'bindings/python/llvm', buildpath/"bindings/python/llvm-#{suffix}"
      python.site_packages.install buildpath/"bindings/python/llvm-#{suffix}"
      # Install clang tools and bindings if requested.
      mv buildpath/'tools/clang/bindings/python/clang', buildpath/"tools/clang/bindings/python/clang-#{suffix}"
      python.site_packages.install buildpath/"tools/clang/bindings/python/clang-#{suffix}" if build.include? 'with-clang'
    end

    # Link executables to bin and add suffix to avoid conflicts
    mkdir_p bin
    Dir.glob(install_prefix/'bin/*') do |exec_path|
      exec_file = File.basename(exec_path)
      ln_s exec_path, bin/"#{exec_file}-#{suffix}"
    end

    # Also link man pages
    mkdir_p share/'man/man1'
    Dir.glob(install_prefix/'share/man/man1/*') do |manpage|
      manpage_base = File.basename(manpage, '.1')
      ln_s manpage, share/"man/man1/#{manpage_base}-#{suffix}.1"
    end
  end

  def test
    system "#{bin}/llvm-config-#{suffix}", "--version"
  end

  def caveats
    suffix = `#{lib}/llvm-#{version}/bin/clang --version`.split("\n").first.slice(/\d\.\d/)
    s = ''
    s += python.standard_caveats if python
    if build.include? 'with-libcxx'
      include_path = HOMEBREW_PREFIX/"lib/llvm-#{suffix}/c++/v1"
      libs_path = HOMEBREW_PREFIX/"lib/llvm-#{suffix}/usr/lib"
      s += <<-EOS.undent

      To link to libc++ built here, please adjust your $CXX as following:
      clang++-#{suffix} -stdlib=libc++ -nostdinc++ -I#{include_path} -L#{libs_path}
      EOS
    end
    s
  end

end
