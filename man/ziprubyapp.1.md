ziprubyapp (1) - Make an executable Ruby script bundle using zip archive
====

## SYNOPSIS

    ziprubyapp [options] {directory | file ...}

    Options:
      -C, --compress[=VAL]             compression level
      -o, --output=FILE                output file
      -m, --main=MOD                   name of main module to be loaded
	  -T, --text-archive               use text-based archive format
      -B, --base64                     encode archive with BASE64
      -D, --provide-data-handle        provide DATA pseudo filehandle
      --help                           show help

## DESCRIPTION

This program bundles several Ruby module files and wraps them as an
"executable" zip archive.  An output file can be invoked as a Ruby
script, or (if a source file contains a "`#!`" line) as a directly
executable command.  Also, it can be handled by (almost every) zip
archiver as an "sfx" file.

Inside Ruby scripts, the language's `require` facility is extended so
that The program can simply use `require` or `require-relative`
statements to load the contained modules, without modifying the
`$:` variable.

## OPTIONS

### ARGUMENTS

* directory

  If there are only one argument and it is a name of directory, All
  `*.rb` files under that directory (recursively) are included.  The
  directory name itself is truncated.

* files

  Otherwise, all files specified in the argument are included.

### INPUT/OUTPUT OPTIONS

* --main, -m

  Specify the main module which is automatically loaded.  Also, a
  "she-bang" line and continuous comment lines are copied from the main
  module to the output.

  If a directory is specified in the argument, and there is a `__main__.rb`
  file on top of the directory, that file will be used.  Otherwise, the
  main module must be explicitly specified.

* --output, -o

  Specify the name of the output file.

  If omitted, either the name of the source directory or the base name
  of the main module is taken, with a postfix '`.rbz`' is appended.

  It is always safer to specify the output file.
  
### ARCHIVE OPTIONS

* --compress, -C

  Specify the compression level for the Deflate algorithm.

  If `-C` is specified without a digit, the highest level 9 is set.

  If not specified at all, the files are not compressed.
  It makes the content of the script almost transparently visible.
  Also, the script will not load zlib and other libraries run-time.

  Outputs generated without `-C` options will not contain decompression
  functionality, that means you need to add `-0` or similar options
  when you modify the contents with zip archivers.

* --base64, -B

  It will encode the embedded ZIP archive with Base64 encoding.  It
  makes the script about 33% larger and also loses zip-transparent
  behavior as an sfx file, in trade for making the output script
  ASCII-clean.

* --text-archive, -T

  It will use its own plaintext archive format for storing modules.
  The output will not be compatible with zip archivers.

  Output scripts generated with this option will be plaintext, if all
  input modules are plaintext in ASCII or some specific
  ASCII-compatible encoding.  In addition to that, it is easier to
  modify its content by hand, because the format uses no byte-oriented
  structure.

  This format will be useful when (1) you need to edit module sources
  embedded in outputs by text editors, or (2) when the whole source
  code must be transparently visible for auditing or inspections (if
  even `-C0` is unsatisfactory).

  The option combination with `-B` is possible, but it is not very
  meaningful.

### CONTENT HANDLING OPTIONS

* --provide-data-handle, -D

  Simulate the DATA file handle for the main module.
  If enabled, it will set `DATA` constant to a simulated pseudo
  file handle, providing the script data after `__END__` token.

  If the main module does not contain the token, it is ignored.

  It is implemented with StringIO in Ruby.  For both performance and
  simplicity, the relative position of the `__END__` token in the
  input is remembered when the script is generated.  If you replace
  the main module by zip archivers, the data will be broken.

## APIS

There are currently no APIs visible to user scripts except import
hooks.  Module `ZipRubyApp` is provided in the zipped script, so if
you need to change some behavior upon packaging, something like

    unless defined? ZipRubyApp
      $:.unshift(__dir__)
    end

can be used.

## LIMITATIONS

* Only pure Ruby scripts or modules can be loaded from zip
  archive. Dynamic loading (*.so, *.dll) will not be available.

* `__FILE__` tokens in the archived file will have virtual values
  of "_archivename_/_modulename_", which does not exist in the real
  file system.  This also holds for the "main script" to be referred
  to.  It means that the common technique for making a "dual-use"
  module/script "`if __FILE__ == $0`" will not work.  Instead, please
  provide a short entry script as a main script.

* For compactness (and minimal dependency only to core modules), an
  embedded parser for zip archives is extremely simple.  It can not
  parse archives with any advanced features or partially-broken
  archives.  If you modify the packed archive using usual zip
  archivers, be aware of that.

* All files are decoded into the memory at the beginning of the
  program execution.  It is not wise to include unneeded files into
  the archive.

## IMPLEMENTATION

A zip archive of module files are stored in the `DATA` section.  A
minimal parser for Zip archives is embedded to the output script, and
it will extract the source codes of all modules to an on-memory
storage at the start-up.  The functions `require` and `require_relative`
in the Kernel module is extended load those modules.

## DEPENDENCIES

Zipped scripts generated by this command will not depend on any
external modules, except those included in the core modules of Ruby
distributions as of version 2.3.1.

This command itself is depending on the `zip` command from Info-Zip.
It must be available in the command search path.

## REFERENCE

 * [Homepage](https://www.github.com/yoiwa-personal/ziprubyapp)

 * [Python's "zipapp" implementation](https://docs.python.org/en/3/library/zipapp.html)

## AUTHOR/COPYRIGHT

Copyright 2019 Yutaka OIWA <yutaka@oiwa.jp>.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

As a special exception to the Apache License, outputs of this
software, which contain a code snippet copied from this software, may
be used and distributed under terms of your choice, so long as the
sole purpose of these works is not redistributing the code snippet,
this software, or modified works of those.  The "AS-IS BASIS" clause
above still applies in these cases.

(In short, you can freely use this software to package YOUR software
and the Apache License will not apply for YOURS.)
