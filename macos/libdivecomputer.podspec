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
    'DEFINES_MODULE' => 'YES'
  }
  
  s.swift_version = '5.0'
  
  # XCFramework (contains static library)
  s.vendored_frameworks = 'Frameworks/libdivecomputer.xcframework'
  
  # System frameworks
  s.frameworks = 'Foundation', 'CoreBluetooth'
end