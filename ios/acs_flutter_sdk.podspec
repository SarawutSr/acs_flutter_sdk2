#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint acs_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'acs_flutter_sdk'
  s.version          = '0.1.1'
  s.summary          = 'Flutter plugin for Microsoft Azure Communication Services'
  s.description      = <<-DESC
A comprehensive Flutter plugin that provides a wrapper for Microsoft Azure Communication Services (ACS),
enabling voice/video calling, chat, SMS, and identity management capabilities in Flutter applications.
                       DESC
  s.homepage         = 'https://github.com/BurhanRabbani/acs_flutter_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Burhan Rabbani' => 'burhanrabbani@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Azure Communication Services dependencies
  s.dependency 'AzureCommunicationCalling', '~> 2.15.1'
  s.dependency 'AzureCommunicationChat', '~> 1.3.6'
  # AzureCommunicationCommon will be resolved automatically by Calling and Chat dependencies

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'acs_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
