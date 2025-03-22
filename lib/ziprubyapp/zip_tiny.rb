require 'zlib'
require 'stringio'

module ZipRubyApp; end

class ZipRubyApp::ZipTiny
  class CompressEntry
    def initialize(fname:, content:, mtime:, source: nil, parent: nil)
      @fname = fname
      @content = content.force_encoding("ASCII-8BIT")
      @mtime = mtime
      @source = source
      @parent = parent
      @compressflag = nil
      @cdata = nil
      @zipflags = nil
    end

    attr_reader :fname, :content, :mtime, :cdata, :zipflags, :source

    # Compress a single entry for zip.  Internally/automatically called
    # from make_zip.
    #
    #  * self: an entry, created by prepare_zip or prepare_zip_entry.
    #  * compressflag: an integer 0--9, corresponding to zlib/zip flags.
    #
    # The self is updated to contain compressed data stream.
    def compress(compressflag)
      return if @compressflag == compressflag
      content = @content
      cdata = content

      if @parent && content.length > @parent.sizelimit
        raise "#{ent[:fname]}: too large data"
      end

      zipflags = [0, 10, 0]

      if (compressflag >= 1)
        zstream = Zlib::Deflate.new(compressflag, -15)
        cdata = zstream.deflate(content, Zlib::FINISH).force_encoding("ASCII-8bit")
        zstream.close
        zipflags = [8, 20, (compressflag > 7) ? 1 : (compressflag > 2) ? 0 : 2]
      end

      $stderr.printf("compressing %s: %d -> %d\n", ent[:fname], content.length, cdata.length) if @debug
      # undo compression if it is not shrunk
      if content.length <= cdata.length
        cdata = content
        zipflags = [0, 10, 0]
      end

      raise "error: #{ent[:fname]}: too large data after compression" if @parent && cdata.length > @parent.sizelimit

      @cdata = cdata
      @zipflags = zipflags
    end

    def is_compressed?
      return @cdata != nil
    end

    def is_really_shrunk?
      return @cdata != nil && @zipflags[0] != 0
    end
  end

  @@sizelimit = 64 * 1048576
  @@debug = false

  def initialize(entries = [])
    @entries = []
    @entries_hash = {}
    @sizelimit = @@sizelimit
    @debug = @@debug
    add_entries(entries)
  end

  def __setopt(sizelimit: (64 * 1048576), debug: false)
    @sizelimit = sizelimit
    @debug = debug
  end

  def self.__setopt(sizelimit: (64 * 1048576), debug: false)
    @@sizelimit = sizelimit
    @@debug = debug
  end

  attr_reader :sizelimit, :debug

  # prepare a single entry to zip.
  #
  # * entname: a file name to be stored in zip file
  # * source: a content to be stores, in one of following
  #   * String "filename": content of the file "filename"
  #   * omitted: content of the file "entname"
  #   * IO handle: data read from the given handle
  #   * Array ["string"]: the content of the string itself
  #
  # * modtime: modification time, if not available from file or handle
  def add_entry(entname, source=nil, modtime=nil)
    content = nil

    raise "duplicated entry #{entname}" if @entries_hash.include?(entname)
    
    if source.is_a?(Array)
      content = source.join("").force_encoding("ASCII-8bit")
      source = [content]
    else
      handle = nil
      handle_close = false
      begin
        if source == nil || source.is_a?(String)
          source = entname if source == nil
          handle_close = true
          handle = File.open(source, "r")
        elsif source.is_a?(IO)
          handle = source
        end
        content = handle.read(@sizelimit)
        content = "" if content == nil
        excess = handle.read(1)
        if excess != nil && excess != ""
          raise "#{source}: size over (#{@sizelimit})"
        end
        content.force_encoding("ASCII-8bit")
        begin
          modtime = handle.stat.mtime
        rescue SystemCallError
          modtime = nil
        end
      ensure
        if handle_close && handle != nil
          handle.close
        end
      end
    end

    modtime = Time.now if modtime == nil
    entry = CompressEntry.new(
      fname: entname,
      content: content,
      mtime: modtime,
      source: source,
      parent: self
    )
    @entries << entry
    @entries_hash[entname] = entry
  end

  # convert Time structure to 32-bit MS-DOS timestamp
  def self.dosdate(unixtime)
    u = unixtime.getlocal
    return 0 if u.year < 1980
    time = u.hour << 11 | u.min << 5 | u.sec >> 1
    date = (u.year - 1980) << 9 | u.month << 5 | u.day
    return (((date & 0xffff) << 16) | (time & 0xffff))
  end

  # Prepare set of entries to be stored in zip.  The input is a list,
  # each of its member is one of the following:
  #   * Array [entname, source, modtime]: arguments to prepare_zip_entry
  #   * String entname: a filename passed to prepare_zip_entry
  #   * Hash internal: a result of prepare_zip_entry, stored as-is.
  # The output is to be passed to make_zip.
  def add_entries(flist)
    flist.each { |e|
      if e.is_a?(String)
        add_entry(e)
      elsif e.is_a?(Array)
        add_entry(*e)
      else
        raise
      end
    }
  end

  def self.prepare_zip(l)
    return self.new(l)
  end

  def each_entry(&proc)
    @entries.each(&proc)
  end

  def include?(name)
    @entries_hash.include?(name)
  end
  
  def find_entry(name)
    if @entries_hash.include?(name)
      @entries_hash[name]
    else
      nil
    end
  end

  # Generate a zip archive data on-memory.
  #
  # = a positional argument
  #  * Array entries: content list to be stored in archive, prepared by prepare_zip.
  # = keyword arguments
  #  * Integer compress: strength of zlib/zip compression, in integer 0--9
  #  * String header: a data prepended to archive.
  #  * String trailercomment: a comment put to the tail of the archive.
  #  * Integer offset: a length of data bytes "to be prepended" to the archive.
  #
  # The output is a binary string for the archive data.
  #
  # It supports generation of "sfx-type" archive, which contains some
  # data before the archive structure.  In zip format, the length of such prepended
  # data affects the zip stream internal.  To generate sfx-type archive, either
  #   * pass the data to be prepended to "header", or
  #   * pass only the length of the data to "offset", and put by yourself afterwards.
  def make_zip(compress: 9, header: "", trailercomment: "", offset: 0)
    pos = offset
    out = StringIO.new('', "wb:ASCII-8bit")
    gheader_accumulate = StringIO.new('', "wb:ASCII-8bit")
    fcount = 0

    out.write(header)
    @entries.each{ |e|
      pos = out.pos + offset

      name = e.fname
      content = e.content
      modtime = e.mtime

      crc = Zlib::crc32(content)

      e.compress(compress)

      cdata = e.cdata
      (compressmethod, versionrequired, flags) = e.zipflags

      name = name.dup.force_encoding("ASCII-8bit")

      flags = ((flags << 1) & 6)
      header = [0x04034b50,
	        versionrequired,
	        flags,
	        compressmethod,
	        self.class.dosdate(modtime),
	        crc,
	        cdata.length,
	        content.length,
	        name.length,
	        0 # extra field len
	       ].pack("VvvvVVVVvv") + name
      gheader = [ 0x02014b50,
	          0x031e, # version made by: 3.0 Unix
	          versionrequired,
	          flags,
	          compressmethod,
		  self.class.dosdate(modtime),
		  crc,
		  cdata.length,
		  content.length,
		  name.length,
		  0, # extra field len
		  0, # file commen length
		  0, # disk number,
		  0, # int file attr,
		  0100644 << 16, # ext file attr: file, -rw-r--r--
		  pos
		].pack("VvvvvVVVVvvvvvVV") + name
      out.write(header)
      out.write(cdata)
      gheader_accumulate.write(gheader)
      fcount += 1
    }
    gheader_accumulate.close
    gheader_accumulate = gheader_accumulate.string

    pos = out.pos + offset
    ecd = [ 0x06054b50,
	    0,
	    0,
	    fcount,
	    fcount,
	    gheader_accumulate.length,
	    pos,
	    trailercomment.length].pack("VvvvvVVv")
    out.write(gheader_accumulate)
    out.write(ecd)
    out.write(trailercomment)
    out.close
    return out.string
  end
end

if __FILE__ == $0
  z = ZipRubyApp::ZipTiny.new([["1", ["1", "1"]],
                               "zip_tiny.rb"]).make_zip()
  print z
end

