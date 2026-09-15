ziprubyapp (1) - Create executable Ruby script bundles using ZIP archives
====

## SYNOPSIS

    ziprubyapp [options] {directory | file ...}

    Options:
      -C, --compress[=VAL]             compression level
      -o, --output=FILE                output file
      -m, --main=MOD                   name of main module to be loaded
      -T, --text-archive               use text-based archive format
      -B, --base64                     encode archive with BASE64
      -D, --provide-data-handle        provide DATA pseudo file-handle
      -I, --includedir=DIR             library path to include
          --[no-]search-includedir     search files within -I directories
          --[no-]trim-includedir       shorten file names for files in -I directories
      --help                           show help

## DESCRIPTION

This program bundles several Ruby module files and wraps them into an
"executable" ZIP archive. The output file can be invoked as a Ruby
script, or (if a source file contains a "`#!`" line) executed directly
as a command. Additionally, it can be handled by almost any ZIP
archiver as a self-extracting ("SFX") file.

Inside Ruby scripts, the language's `require` facility is extended so
that the program can simply use `require` or `require_relative`
statements to load contained modules without modifying the
`$:` (`$LOAD_PATH`) variable.

## OPTIONS

### ARGUMENTS

* directory

  If there is only one argument and it is the name of a directory, all
  `*.rb` files under that directory (recursively) are included. The
  directory path prefix itself is truncated.

* files

  Otherwise, all files specified in the arguments are included.

### INPUT/OUTPUT OPTIONS

* --main, -m

  Specifies the main module that is automatically loaded. A "shebang"
  line and consecutive comment lines are copied from the main module
  to the output.

  If a directory is specified as the argument and a `__main__.rb` file
  exists at the root of that directory, that file is used by
  default. Otherwise, the main module must be explicitly specified.

* --output, -o

  Specifies the name of the output file.

  If omitted, either the name of the source directory or the base name
  of the main module is used, with the extension '`.rbz`' appended.

  Explicitly specifying the output file is always recommended.
  
* --includedir, -I

  Specifies locations to search for input files in addition to the current
  directory.
  If this option is specified multiple times, directories are searched
  in the order specified.

  This option has two separate effects; for example, when '`-Ilib file.rb`'
  is specified on the command line:

  * The command will include '`lib/file.rb`' in the archive if
    '`file.rb`' does not exist in the working directory. This behavior
    can be disabled by specifying '`--no-search-includedir`'.

  * The file '`lib/file.rb`' will be included in the archive as
    '`file.rb`', trimming the library directory prefix. This occurs
    whether the file is specified explicitly or via the `-I`
    option. This behavior can be disabled by specifying
    '`--no-trim-includedir`'.

    If two or more files share the same name after trimming,
    the operation will fail with an error.

### ARCHIVE OPTIONS

* --compress, -C

  Specifies the compression level for the Deflate algorithm.

  If `-C` is specified without a digit, the maximum compression level 9 is set.

  If omitted entirely, files are stored uncompressed.  This makes
  script content almost transparently readable.  Additionally,
  uncompressed scripts will not load `zlib` or other libraries at
  runtime.

  Outputs generated without the `-C` option do not include decompression
  code, which means you must pass `-0` (store) or similar flags
  if modifying the archive content with external ZIP tools.

* --base64, -B

  Encodes the embedded ZIP archive with Base64 encoding. This
  increases script size by approximately 33% and loses ZIP-transparent
  SFX behavior, in exchange for producing an ASCII-clean script.

* --text-archive, -T

  Uses a custom plaintext archive format for storing modules.
  The output will not be compatible with standard ZIP archivers.

  Output scripts generated with this option will be plain text if all
  input modules are plain text in ASCII or ASCII-compatible encodings.
  Additionally, hand-editing contents is easier because the format
  uses no binary structures.

  This format is useful when (1) embedded module sources need to be
  edited with text editors, or (2) source code must remain fully
  transparent for auditing or inspection (where even `-C0` is
  insufficient).

  Combining this option with `-B` is supported, but not particularly useful.

### CONTENT HANDLING OPTIONS

* --provide-data-handle, -D

  Simulates the `DATA` file handle for the main module.
  When enabled, it sets the `DATA` constant to a simulated pseudo-file handle,
  providing script data located after the `__END__` token.

  If the main module does not contain the `__END__` token, this option
  is ignored.

  It is implemented via `StringIO` in Ruby. For performance and
  simplicity, the relative position of the `__END__` token is recorded
  during generation. Replacing the main module via external ZIP
  archivers will invalidate this data.

### OTHER OPTIONS

* --random-seed

  Specifies a seed integer for pseudorandom number generation. Some
  features (e.g., `--text-archive`) use random numbers to generate
  unique byte sequences in the archive, causing outputs for identical
  inputs to vary over time. Specifying a seed ensures deterministic
  output for identical input sets.  Note that this is not a strict
  guarantee; output may still vary slightly across different platform
  environments, machine architectures, or library versions.  The
  primary use case is ensuring reproducible archive outputs for
  version control systems such as Git or Subversion.
  
  In Ruby, seeds are 128-bit integers.

## APIS

There are currently no public APIs exposed to user scripts except
import hooks.  The module `ZipRubyApp` is provided within the zipped
script. If custom behavior is required upon packaging, guard clauses
such as:

    unless defined? ZipRubyApp
      $:.unshift(__dir__)
    end

can be used.

In Ruby, `require_relative` is recommended for loading modules located
in the same directory as the script, and it integrates seamlessly with
this tool.

## LIMITATIONS

* Only pure Ruby scripts or modules can be loaded from ZIP
  archives. Native extensions (`*.so`, `*.dll`) cannot be dynamically loaded.

* The `__FILE__` token in archived files will contain virtual path
  strings in the format "`_archivename_/_modulename_`", which do not
  exist on the real filesystem. This also applies to the main
  script. Consequently, the common "dual-use" idiom `if __FILE__ ==
  $0` will not function as expected. Provide a dedicated entry script
  instead.

* For compactness (and to minimize dependencies to core libraries
  only), the embedded ZIP parser is extremely simplified. It cannot
  parse archives utilizing advanced ZIP features or partially
  corrupted archives. Exercise caution when modifying packed archives
  with external ZIP tools.

* All files are extracted into memory at program startup. Avoid
  including unnecessary large files in the archive.

* Module loading is simulated using `Kernel.eval`, and
  `Kernel.require` is overridden to extend search logic. While
  carefully implemented, unknown side effects may exist or behavior
  may change in future Ruby versions. Unlike Python or Perl, Ruby
  lacks native hooks for extending module resolution.

## IMPLEMENTATION

A ZIP archive containing module files is stored in the `DATA`
section. A minimal parser for ZIP archives is embedded in the output
script to extract module source code into in-memory storage at
startup. The `require` and `require_relative` methods in the `Kernel`
module are overridden to load these in-memory modules.

## DEPENDENCIES

Zipped scripts generated by this command do not depend on external
gems or modules, relying solely on standard libraries included in core
Ruby distributions (version 2.3.1 or later).

## REFERENCES

 * [Homepage](https://www.github.com/yoiwa-personal/ziprubyapp)

 * [zipperlapp](https://www.github.com/yoiwa-personal/zipperlapp)

 * [Python "zipapp" documentation](https://docs.python.org/en/3/library/zipapp.html)

## AUTHOR / COPYRIGHT

Copyright 2019-2025 Yutaka OIWA <yutaka@oiwa.jp>.

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
software, which contain code snippets copied from this software, may
be used and distributed under terms of your choice, as long as the
sole purpose of these works is not to redistribute the code snippets,
this software, or modified works thereof. The "AS-IS BASIS" clause
above still applies in these cases.

(In short, you can freely use this software to package YOUR software
and the Apache License will not apply to YOURS.)

