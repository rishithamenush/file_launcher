#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint file_launcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'file_launcher'
  s.version          = '0.2.0'
  s.summary          = 'Open local files with the default macOS app, with a share-picker fallback.'
  s.description      = <<-DESC
Open local files with the default macOS app, with a share-picker fallback.
                       DESC
  s.homepage         = 'https://pub.dev/packages/file_launcher'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Rishitha Menusha'
  s.source           = { :path => '.' }
  s.source_files = 'file_launcher/Sources/file_launcher/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
