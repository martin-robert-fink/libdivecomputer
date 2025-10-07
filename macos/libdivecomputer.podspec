Pod::Spec.new do |s|
  s.name             = 'libdivecomputer'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for libdivecomputer'
  s.description      = <<-DESC
A Flutter plugin that wraps the libdivecomputer C library for macOS.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.13'

  s.pod_target_xcconfig = { 
  'DEFINES_MODULE' => 'YES',
  'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/libdivecomputer.xcframework/macos-arm64/Headers"',
  'USER_HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/libdivecomputer.xcframework/macos-arm64/Headers"'
  }

  s.public_header_files = 'Classes/libdivecomputer.h'
  s.swift_version = '5.0'
  # Use vendored_libraries for .a files, not vendored_frameworks
  s.vendored_libraries = 'Frameworks/libdivecomputer.xcframework/macos-arm64/libdivecomputer.a'
  s.preserve_paths = 'Frameworks/libdivecomputer.xcframework/**/*'
  
  # System frameworks
  s.frameworks = 'Foundation', 'CoreBluetooth'
end