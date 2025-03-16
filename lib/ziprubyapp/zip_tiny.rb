require 'zlib'
require 'stringio'

module ZipTiny
  @@sizelimit = 64 * 1048576
  @@debug = false

  module_function

  def ZipTiny::__setopt(sizelimit: (64 * 1048576), debug: false)
    @@sizelimit = sizelimit
    @@debug = debug
  end

  def make_zipdata(entname, source=nil, modtime=nil)
    content = nil

    if source.is_a?(Array)
      content = source.join("")
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
        content = handle.read(@@sizelimit)
        excess = handle.read(1)
        if excess != nil && excess != ""
          raise "#{source}: size over (#{@@sizelimit})"
        end
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
    return {
      fname: entname,
      content: content,
      mtime: modtime
    }
  end

  def dosdate(unixtime)
    u = unixtime.getlocal
    return 0 if u.year < 1980
    time = u.hour << 11 | u.min << 5 | u.sec >> 1
    date = (u.year - 1980) << 9 | u.month << 5 | u.day
    return (((date & 0xffff) << 16) | (time & 0xffff))
  end

  def prepare_zip(flist)
    flist.map { |e|
      if e.is_a?(Hash)
        e
      elsif e.is_a?(String)
        make_zipdata(e)
      elsif e.is_a?(Array)
        make_zipdata(*e)
      else
        raise
      end
    }
  end

  def compress_entry(ent, compressflag)
    return ent if ent.member?(:cdata)

    content = ent[:content]
    cdata = content

    raise "#{ent[:fname]}: too large data" if content.length > @@sizelimit

    compressmethod, versionrequired, flags = 0, 10, 0

    if (compressflag >= 1)
      zstream = Zlib::Deflate.new(compressflag, -15)
      cdata = zstream.deflate(content, Zlib::FINISH)
      zstream.close
      compressmethod, versionrequired = 8, 20
      flags = (compressflag > 7) ? 1 : (compressflag > 2) ? 0 : 2
    end

    $stderr.printf("compressing %s: %d -> %d\n", ent[:fname], content.length, cdata.length) if @@debug
    # undo compression if it is not shrunk
    if content.length <= cdata.length
      cdata = content
      compressmethod, versionrequired, flags = 0, 10, 0
    end

    raise "error: #{ent[:fname]}: too large data after compression" if cdata.length > @@sizelimit

    ent[:cdata] = cdata
    ent[:compressmethod] = compressmethod
    ent[:versionrequired] = versionrequired
    ent[:flags] = flags
  end

  def make_zip(entries, compress: 9, header: "", trailercomment: "", offset: 0)
    pos = offset
    out = StringIO.new(String.new, "rb+")
    gheader_accumulate = StringIO.new(String.new, "rb+")
    fcount = 0

    out.write(header)
    entries.each{ |e|
      pos = out.pos + offset

      if e.is_a?(Array) or e.is_a?(String)
        e = make_zipdata(*e)
      end

      name = e[:fname]
      content = e[:content]
      modtime = e[:mtime]

      crc = Zlib::crc32(content)

      compress_entry(e, compress)

      cdata = e[:cdata]
      compressmethod = e[:compressmethod]
      versionrequired = e[:versionrequired]
      flags = e[:flags]

      flags = ((flags << 1) & 6)
      header = [0x04034b50,
	        versionrequired,
	        flags,
	        compressmethod,
	        dosdate(modtime),
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
		  dosdate(modtime),
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
    gheader_accumulate.rewind
    gheader_accumulate = gheader_accumulate.read

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
    out.rewind
    return out.read
  end
end

if __FILE__ == $0
  z = ZipTiny::make_zip([["1", ["1", "1"]],
                         "zip_tiny.rb"])
  print z
end

