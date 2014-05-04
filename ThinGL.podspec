#
#  Be sure to run `pod spec lint ThinGL.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "ThinGL"
  s.version      = "0.2.0"
  s.summary      = "Thin abstraction layer for iOS OpenGL-ES2"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/ykst/ThinGL"
  s.license      = { :type => 'MIT', :file => 'MIT-LICENSE.txt' }

  s.author       = { "Yohsuke Yukishita" => "ykstyhsk@gmail.com" }

  s.source       = { :git => "https://github.com/ykst/ThinGL.git", :tag => "0.2.0" }

  s.source_files  = 'Sources', 'src/*.{h,c,m}'
  s.exclude_files = 'Makefile'
  s.prefix_header_file = 'src/Utility.h'
  s.public_header_files = 'src/TGL*.h'
  s.requires_arc = true
end
