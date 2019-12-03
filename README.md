# ziprubyapp - Make an executable ruby script bundle using zip archive

This program bundles several Ruby module files and wraps them as an
"executable" zip archive.  An output file can be invoked as a Ruby
script, or (if a source file contains a `#!` line) as a directly
executable command.  Also, it can be handled by (almost every) zip
archiver as an "sfx" file.

Inside Ruby scripts, the language's `require` facility is extended so
that The program can simply use `require` or `require-relative`
statements to load the contained modules, without modifying the
`$:` variable.

For detailed usage, see
[a manual page in markdown format](man/ziprubyapp.1.md), or (if
installed from gem) manual pages in man or html format (run `gem
contents ziprubyapp` for locations).

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
