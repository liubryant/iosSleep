platform :ios, '16.0'

target 'iosSleep' do
  use_frameworks!

  # GroMore(穿山甲) 广告 SDK
  pod 'Ads-CN-Beta', '7.6.0.3', :subspecs => ['CSJMediation-Only']

  # 友盟统计 SDK
  pod 'UMCommon'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      config.build_settings.delete('VALID_ARCHS[sdk=iphonesimulator*]')
    end
  end
end
