#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint file_launcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'file_launcher'
  s.version          = '0.1.0'
  s.summary          = 'Open local files with native viewers on iOS and Android, with a share-sheet fallback and no storage permissions.'
  s.description      = <<-DESC
Open local files with native viewers on iOS and Android, with a share-sheet fallback and no storage permissions.
                       DESC
  s.homepage         = 'https://pub.dev/packages/file_launcher'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Rishitha Menusha'
  s.source           = { :path => '.' }
  s.source_files = 'file_launcher/Sources/file_launcher/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'file_launcher_privacy' => ['file_launcher/Sources/file_launcher/PrivacyInfo.xcprivacy']}
end
