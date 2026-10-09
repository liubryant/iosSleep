platform :ios, '16.0'

target 'iosSleep' do
  use_frameworks!

  # GroMore(穿山甲) 广告 SDK
  pod 'Ads-CN-Beta', '7.6.0.3', :subspecs => ['CSJMediation-Only']

  # 友盟统计 SDK
  pod 'UMCommon'

  # 本地睡眠声音识别（YAMNet）
  pod 'TensorFlowLiteC', '~> 2.17.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Keep every generated Pods target aligned with the app target. Some
      # third-party podspecs still declare iOS 9/11/12, which newer Xcode
      # versions report as unsupported deployment targets.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      config.build_settings.delete('VALID_ARCHS[sdk=iphonesimulator*]')
    end
  end
end
