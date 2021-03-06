#!gem build

Gem::Specification.new do |s|
  s.name        = 'ziprubyapp'
  s.version     = '1.1.0'
  s.licenses    = ['Apache-2.0']
  s.summary     = 'Make an executable ruby script bundle using zip archive'
  s.executables = 'ziprubyapp'
  s.description = open("README.md") {|f| f.read =~ /\A# (.*)\nFor/m; $1 }
  s.authors     = ["Yutaka OIWA"]
  s.email       = 'yutaka@oiwa.jp'
  s.files       = ["man/ziprubyapp.1", "man/ziprubyapp.1.html"]
  s.homepage    = 'https://github.com/yoiwa-persona/ziprubyapp/'
  s.metadata    = { "source_code_uri" => "https://github.com/yoiwa-personal/ziprubyapp/" }
  s.requirements << 'zip from Info-zip'
end
