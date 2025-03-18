#!/usr/bin/env ruby
# -*- ruby -*-
# ziprubyapp - Make an executable ruby script bundle using zip archive
#
# https://github.com/yoiwa-personal/ziprubyapp/
#
# Copyright 2019-2025 Yutaka OIWA <yutaka@oiwa.jp>.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# As a special exception to the Apache License, outputs of this
# software, which contain a code snippet copied from this software, may
# be used and distributed under terms of your choice, so long as the
# sole purpose of these works is not redistributing the code snippet,
# this software, or modified works of those.  The "AS-IS BASIS" clause
# above still applies in these cases.

VERSION = "2.0.1"

require 'optparse'
require 'find'
require 'stringio'
require_relative 'zip_tiny.rb'

module ZipRubyApp; end

class ZipRubyApp::Generator
  @@debug = false

  def die str; $stderr.print("Error: #{str}\n"); exit 1; end

  def canonicalize_filename(fname, fixedprefix)
    fname = fname.gsub(%r(/+), "/")

    fname = fname.split('/')
    pos = 0
    
    while pos < fname.length do
      pos = 0 if pos <= -1
      if fname[pos] == '.'
        fname.slice!(pos)
        redo
      elsif (pos >= 1 &&
             fname[pos] == '..' &&
             fname[pos - 1] != '' && # not parent-of-root
             fname[pos - 1] != '..') # parent of parent
        fname.slice!(pos)
        fname.slice!(pos - 1)
        pos -= 1
        redo
      end
      pos += 1
    end

    fname = fname.join('/')
    
    fname = fname.sub(%r@\A(\./)+@, "")
    while (fname.sub!(%r@/./@, "/")); end
    while (fname.sub!(%r@(/[^/]+/../)@, "/")); end

    ename = fname
    if (@trimlibname)
      if fixedprefix != nil
        ename = ename.delete_prefix(fixedprefix + "/")
      else
        @includedir.each { |l|
          libdir = l + "/"
          if ename.start_with?(libdir)
            ename = ename.delete_prefix(libdir)
            break
          end
        }
      end
    end
    die "#{fname}: name is absolute\n" if ename =~ %r@\A/@
    die "#{fname}: name contains ..\n" if ename =~ %r@(\A|/)../@
    return [fname, ename]
  end

  def add_file(fname, fixedprefix)
    # behavior of main mode:
    #  1: no op; do later
    #  2: add if first
    #  3: noop

    fname, ename = canonicalize_filename(fname, fixedprefix)

    die "cannot find #{fname}" unless File.exist?(fname)
    die "#{fname} is not a plain file" unless File.file?(fname)
    if @enames.include?(ename)
      if fname != @enames[ename]
        die "duplicated files: #{fname} and #{@enames[ename]} will be same name in the archive"
        # else: skip
      end
    else
      if (@maintype == 1)
        # do it later
      elsif @maintype == 2
        @main = ename if @main == nil
        @possible_out = ename if @possible_out == nil
      end
      @enames[ename] = fname
      @files << [ename, fname]
    end
  end

  def add_dir(fname, prefix)
    Find.find(fname) {|f|
      unless f =~ %r((\A|\/)\.[^\/]*\z)
        add_file(f, prefix) if f =~ /\.rb\z/
      end
    }
  end

  def process(argv)
    compression = 0
    out = nil
    mainopt = nil
    base64 = false
    textarchive = false
    simulate_data = false

    @includedir = []
    @sizelimit = 64 * 1048576

    @trimlibname = 1
    searchincludedir = 1

    opt = OptionParser.new

    opt.banner += " {directory | files ...}"

    opt.on('-C', '--compress[=VAL]', Integer, "compression level") { |v| compression = (v == nil) ? 9 : v }
    opt.on('-o FILE', '--output=FILE', "output file") { |v| out = v }
    opt.on('-m MOD', '--main=MOD', "name of main module to be loaded") { |v| mainopt = v }
    opt.on('-T', '--text-archive', "use text-based archive format") { |v| textarchive = true }
    opt.on('-B', '--base64', "encode archive with BASE64") { |v| base64 = true }
    opt.on('-D', '--provide-data-handle', "provide DATA pseudo filehandle") { simulate_data = true }
    opt.on('-I DIR', '--includedir=DIR', String, "library path to include") { |v| @includedir << v }
    opt.on('--[no-]search-includedir', "search files within -I directories (default true)") { |v| searchincludedir = v }
    opt.on('--[no-]trim-includedir', "shorten file names for files in -I directories (default true)") { |v| @trimlibname = v }
    opt.on('--sizelimit=INT', Integer, "maximal file size to process (for both pack and unpack)") { |v| @sizelimit = (v || 64 * 1048576) }
    opt.on('--random-seed=INT', Integer, "seed for the pseudorandom number") { |v| srand v }
    opt.version=VERSION

    begin
      opt.parse!(argv)
    rescue OptionParser::ParseError => e
      $stderr.puts "Error: #{e.to_s}\n"
      $stderr.puts opt.help
      exit(2)
    end

    if (argv.length == 0)
      puts opt.help
      exit(2)
    end

    @possible_out = nil
    @main = nil
    dir = nil
    @maintype = 0

    # determine main file and output name
    # argument types:
    #   type 1: a single directory dir, no main specified
    #     -> include all files in dir, search for the main file (main.rb or __main__.rb), output dir.plz
    #   type 2: a set of files
    #     -> specified files included, first argument must be .rb file, output first.plz
    #   type 3: main file specified
    #     -> specified files included, main file must be included, output main.plz

    @files = Array.new
    @enames = Hash.new

    @includedir.map! { |f|
      f.sub(/\/+\z/, "")
    }

    if (mainopt != nil)
      @main = mainopt
      @possible_out = @main
      @maintype = 3
    end

    if (argv.length == 1 and File.directory? argv[0])
      dir = argv[0]
      dir = dir.sub(/\/+\z/, "")
      @possible_out = dir
      @includedir << dir
      searchincludedir = false
      @trimlibname = true
      @maintype = 1 unless @maintype == 3
    else
      @maintype = 2 unless @maintype == 3
    end

    if (mainopt != nil)
      @main = canonicalize_filename(@main)[1]
    end

    argv.each { |f|
      foundprefix = nil
      unless File.exist?(f)
        if searchincludedir
          @includedir.each { |l|
            ff = "#{l}/#{f}"
            if File.exist?(ff)
              foundprefix = l
              f = ff
              break
            end
          }
        end
      end
      if File.file?(f)
        add_file(f, foundprefix)
      elsif File.directory?(f)
        f = f.sub(/\/+\z/, "")
        add_dir(f, foundprefix)
      else
        die "file not found: #{f}" unless File.exist?(f)
        die "file unknown type: #{f}"
      end
    }

    if @maintype == 1
      ["__main__.rb", "main.rb"].each { |f|
        if @enames.include?(f)
          @main = f
          break
        end
      }
    end

    die "no main files guessed" unless @main != nil

    if (out == nil)
      if (@possible_out == nil or @possible_out == '.')
        die("cannot guess name")
      end
      out = File.basename @possible_out
      out = out.sub(/(\.rb)?\z/, '.rbz')
      print "output is set to: #{out}\n"
    end

    if @maintype != 3 || mainopt != @main
      print "using #{@main} as main script\n"
    end

    if not @enames.include?(@main)
      die "no main file #{@main.inspect} will be contained in archive"
    end

    @files.each {|f|
      printf("%s <- %s\n", f[0], f[1])
    }

    die "bad --compress=#{compression}" unless 0 <= compression && compression <= 9

    ZipTiny::__setopt(sizelimit: @sizelimit, debug: @@debug)

    @files = ZipTiny::prepare_zip(@files)

    # consult main script for top comments and she-bang

    # uses data structure internal to ZipTiny
    mainent = @files.select { |e| e[:fname] == @main }
    raise if mainent.length != 1
    mainent = mainent[0]

    shebang = ''

    StringIO::open(mainent[:content], "rb") { |mainf|
      mainf.each_line { |line|
        break unless /^#/ =~ line
        shebang << line
      }
    }

    mode = 0o666
    mode = 0o777 if (/\A#!/ =~ shebang)

    if simulate_data
      require 'ripper'

      StringIO::open(mainent[:content], "rb") { |mainf|
        # depending on that ripper stops reading at __END__ token
        lex = Ripper.lex(mainf)
        if lex[-1] and lex[-1][1] == :on___end__
          simulate_data = mainf.pos
        else
          simulate_data = false
        end
      }
    end

    # no quotation support for ruby (not needed)

    headerdata, zipdata = create_sfx(@files, shebang, textarchive, compression, base64, simulate_data)

    print "writing to #{out}\n"

    open(out, "wb", mode) { |of|
      of.write headerdata
      of.write zipdata
    }
  end

  def create_sfx(files, shebang, textarchive, compression, base64, simulate_data)
    $stderr.print("create_sfx: b64 #{base64}, simdata #{simulate_data}\n") if @@debug

    quote = nil
    if (base64)
      require 'base64'
      quote = 'base64'
    end

    # prepare launching script

    config = {main: @main, dequote: quote, simulate_data: simulate_data, sizelimit: @sizelimit}
    features = ["MAIN"] +
               (textarchive ? ["TEXTARCHIVE"] : ["ZIPARCHIVE"]) +
               (quote ? ["QUOTE"] : []) +
               (compression != 0 ? ["COMPRESSION"] : []) +
               (simulate_data ? ["SIMULATEDATA"] : [])

    script = script(
      features,
      {'CONFIG' => config.to_s,
       'PKGNAME' => 'ZipRubyApp::ARCHIVED__'})

    header = shebang + "\n" + script

    zipdata = nil

    if textarchive
      zipdata = create_textarchive(files)
    else
      offset = base64 ? 0 : header.length
      zipdata = ZipTiny::make_zip(files,
                                  compress: compression,
                                  header: "",
                                  trailercomment: "",
                                  offset: offset)
    end
    if (base64)
      zipdata = Base64.encode64(zipdata)
    end

    return [header, zipdata]
  end

  def create_textarchive(files)
    zipdat = StringIO.new

    files.each { |e|
      # uses data structure internal to ZipTiny
      fname = e[:fname]
      dat = e[:content]

      while(true)
        sep = "----TEXTARCHIVE-%08d----------------" % rand(100000000)
        break if ! dat.include?(sep) && ! fname.include?(sep)
      end
      zipdat.write("TXD\n")
      zipdat.write(sep, "\n")
      zipdat.write(fname)
      zipdat.write("\n", sep, "\n")
      zipdat.write(dat)
      zipdat.write("\n", sep, "\n")
    }
    zipdat.write("TXE\n")

    zipdat.close
    return zipdat.string
  end

  def script(features, replace)
    script = <<'EOS'
# This script is packaged by ziprubyapp

module ZipRubyApp; end
module @@PKGNAME@@
  SOURCES = Hash.new
  FAKEPATH_ROOT = File.expand_path(__FILE__)
  FAKEPATH_REGEX = /\A#{Regexp.quote FAKEPATH_ROOT}\/(.+)/
  FILTER_REGEX = /\A#{Regexp.quote __FILE__}:\d+:in `(require|require_relative|call|eval|load|<main>|block \(2 levels\) in <module:Kernel>)'\z/
  CONFIG = @@CONFIG@@
  RUBYVER = (RUBY_VERSION.split(".").take(3).map.with_index {|x, i| x.to_i * 1000 ** (2 - i)}.inject(0, :+))

  class ZippedModule
    def self.search(spec)
      return @@PKGNAME@@::SOURCES[spec]
    end

    def initialize(spec, code)
      @spec = spec.untaint
      @encoding = %r/\A(?:#![^\n]*\r?\n)?#.*coding\s*[=:]\s*([\w\-]+)/i =~ code ? $1 : 'UTF-8'
      @code = code.untaint.force_encoding(@encoding)
      @lock = Thread::Mutex.new
      @loaded = false
    end

    def load(justload=false)
      r = nil
      fakepath = FAKEPATH_ROOT + "/" + @spec
      unless justload
        return false if @loaded
        begin
          @lock.lock
        rescue ThreadError
          raise LoadError.new("#{@spec}: recursive loading")
        end
      end
      begin
        SCRIPT_LINES__[fakepath] = @code.lines if Object.constants.include?(:SCRIPT_LINES__)
        r = eval(@code, TOPLEVEL_BINDING, fakepath, 1)
        unless justload
          $LOADED_FEATURES << fakepath unless justload
          @loaded = true
        end
      ensure
        @lock.unlock unless justload
      end
      return justload ? r : true
    end

    def to_s; "#<#{self.class}: @spec=#{@spec.inspect}, @code=#{@code[0, 10].inspect}... (#{@code.length} bytes)>"; end
    alias inspect to_s
    attr_reader :code, :spec
  end

  def self.fatal str; $stderr.print("Error processing zipped script #{$0.inspect}: #{str}\n"); exit 255; end

  def self.filter_err()
    return if $-d or ! $!
    n = 0
    n += 1          while $@.length > n && @@PKGNAME@@::FILTER_REGEX !~ $@[n]
    $@.delete_at(n) while $@.length > n && @@PKGNAME@@::FILTER_REGEX =~ $@[n]
  end

  def self.get_main; get_module(self::CONFIG[:main]); end

  @data = DATA
  @data.set_encoding('ASCII-8bit')

  def self.read_data(n)
    return '' if n == 0
    d = @data.read(n)
    return d if d && d.length == n
    raise LoadError.new("zip archive truncated: #{n}, #{d.inspect}")
  end

  def self.get_module(spec)
    return ZippedModule.search(FAKEPATH_REGEX =~ spec ? $1 : spec)
  end

#BEGIN QUOTE
  case self::CONFIG[:dequote]
  when 'base64'
    require 'base64'
    require 'stringio'
    dat = Base64.decode64(@data.read(nil))
    @data.close
    @data = StringIO.new(dat, "rb")
  end
#END QUOTE

  while true do
    hdr = read_data(4)
    case hdr
#BEGIN ZIPARCHIVE
    when "PK\3\4"
      # per_file zip header
      (_, flags, comp, _, _, crc, csize, size, fnamelen, extlen) =
        read_data(26).unpack("vvvvvVVVvv")
      fname = read_data(fnamelen)
      read_data(extlen)
      fatal "#{fname}: unsupported: deferred length" if (flags & 0x8 != 0)
      fatal "#{fname}: unsupported: 64bit length" if size == 0xffffffff
      fatal "#{fname}: too big data (u:#{size})" if size > self::CONFIG[:sizelimit]
      fatal "#{fname}: too big data (c:#{csize})" if csize > self::CONFIG[:sizelimit]
      dat = read_data(csize)
      if (comp == 0)
        fatal "#{fname}: malformed data: bad length" unless csize == size
#BEGIN COMPRESSION
      elsif (comp == 8)
        require 'zlib'
        zstream = Zlib::Inflate.new(-15)
        buf = zstream.inflate(dat)
        buf << zstream.finish
        zstream.close
        dat = buf
        fatal "#{fname}: malformed data: bad length" unless dat.length == size
        fatal "#{fname}: Inflate failed: crc mismatch" unless Zlib::crc32(buf) == crc
#END COMPRESSION
      else
        fatal "#{fname}: unsupported compression (type #{comp})"
      end

      SOURCES[fname] = ZippedModule.new(fname, dat)
    when "PK\1\2"
      break # central directory found. exiting.
    when "PK\5\6"
      fatal "malformed or empty archive"
#END ZIPARCHIVE
#BEGIN TEXTARCHIVE
    when "TXD\n"
      bar = @data.gets("\n") or fatal "truncated data"
      d = "\n" + bar
      fname = @data.gets(d) or fatal "truncated data"
      fname.chomp!(d)
      dat = @data.gets(d) or fatal "truncated data"
      dat.chomp!(d)
      SOURCES[fname] = ZippedModule.new(fname, dat)
    when "TXE\n"
      break
#END TEXTARCHIVE
    else
      fatal "malformed data"
    end
  end
  @data.close
#BEGIN SIMULATEDATA

  if self::CONFIG[:simulate_data]
    require 'stringio'
    pos = self::CONFIG[:simulate_data]
    str = self.get_main().code
    str = str.byteslice(pos, str.bytesize - pos)
    Object.send(:remove_const, :DATA)
    Object.send(:const_set, :DATA, StringIO.new(str))
  end
#END SIMULATEDATA
end

module Kernel
  define_method :require, Proc.new { |_require|
    Proc.new { |path|
      mypath = path.respond_to?(:to_path) ? path.to_path : path # see rubygems.require
      mypath = "" + mypath                                      # rip off all dirty hacks if any
      raise SecurityError.new("Insecure operation - require") if @@PKGNAME@@::RUBYVER < 2007000 && $SAFE > 0 && mypath.tainted?
      mypath += ".rb" unless /.rb\z/ =~ mypath

      mod = @@PKGNAME@@.get_module(mypath)
      if mod
        return false if $LOADED_FEATURES.include?(mod.spec)
        mod.load
        return true
      else
        begin _require.call(path) ensure @@PKGNAME@@.filter_err() end
      end
    }}.call(Kernel.instance_method(:require).bind(Kernel))
#BEGIN COMMENT
 # Kernel.method(:require) will return non-overridden non-gem method
#END COMMENT

  def require_relative(path)
    loc = caller_locations(1,1)[0].absolute_path
    if @@PKGNAME@@::RUBYVER < 3000000 && @@PKGNAME@@::FAKEPATH_REGEX =~ loc
      require File.expand_path(path, File.dirname(loc).untaint)
    else
      require File.expand_path(path, File.dirname(loc))
      # chain-calling require_relative will use wrong base path
    end
  end
end

begin @@PKGNAME@@.get_main.load(true) ensure @@PKGNAME@@.filter_err() end
__END__
EOS

    while script.gsub!(%r/^#BEGIN\ ([A-Z]+)\n(.*?)^#END\ \1\n/m) { features.include?($1) ? $2 : "" }; end
    script.gsub!(%r/@@([A-Z]+)@@/) { replace[$1] }
    return script
  end
end
ZipRubyApp::Generator::new().process(ARGV)
