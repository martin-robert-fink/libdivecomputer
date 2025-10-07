#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint libdivecomputer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'libdivecomputer'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for libdivecomputer'
  s.description      = <<-DESC
A Flutter plugin that wraps the libdivecomputer C library for iOS.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/libdivecomputer/ios/Frameworks"'
  }
  s.swift_version = '5.0'

  # XCFramework
  s.vendored_frameworks = 'Frameworks/libdivecomputer.xcframework'
  
  # System frameworks
  s.frameworks = 'Foundation', 'CoreBluetooth'
end
