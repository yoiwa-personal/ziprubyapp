#!/usr/bin/ruby
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
require_relative 'sfx_generate.rb'

compression = 0
out = nil
mainopt = nil
base64 = false
textarchive = false
simulate_data = false

includedir = []
searchincludedir = 1
trimlibname = 1

sizelimit = 64 * 1048576

opt = OptionParser.new

opt.banner += " {directory | files ...}"

opt.on('-C', '--compress[=VAL]', Integer, "compression level") { |v| compression = (v == nil) ? 9 : v }
opt.on('-o FILE', '--output=FILE', "output file") { |v| out = v }
opt.on('-m MOD', '--main=MOD', "name of main module to be loaded") { |v| mainopt = v }
opt.on('-T', '--text-archive', "use text-based archive format") { |v| textarchive = true }
opt.on('-B', '--base64', "encode archive with BASE64") { |v| base64 = true }
opt.on('-D', '--provide-data-handle', "provide DATA pseudo filehandle") { simulate_data = true }
opt.on('-I DIR', '--includedir=DIR', String, "library path to include") { |v| includedir << v }
opt.on('--[no-]search-includedir', "search files within -I directories (default true)") { |v| searchincludedir = v }
opt.on('--[no-]trim-includedir', "shorten file names for files in -I directories (default true)") { |v| trimlibname = v }
opt.on('--sizelimit=INT', Integer, "maximal file size to process (for both pack and unpack)") { |v| sizelimit = (v || 64 * 1048576) }
opt.on('--random-seed=INT', Integer, "seed for the pseudorandom number") { |v| srand v }
opt.version=VERSION

begin
  opt.parse!(ARGV)
rescue OptionParser::ParseError => e
  $stderr.puts "Error: #{e.to_s}\n"
  $stderr.puts opt.help
  exit(2)
end

if (ARGV.length == 0)
  puts opt.help
  exit(2)
end

begin
  sfx = ZipRubyApp::SFXGenerate::ziprubyapp(
    ARGV,
    out: out,
    mainopt: mainopt,
    compression: compression,
    base64: base64,
    textarchive: textarchive,
    simulate_data: simulate_data,
    includedir: includedir,
    searchincludedir: searchincludedir,
    trimlibname: trimlibname,
    sizelimit: sizelimit )
rescue ZipRubyApp::CommandError => e
  $stderr.print("Error: #{e.message}\n")
  exit 1
end

