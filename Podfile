platform :ios, '8.0'
use_frameworks!

target 'FoxelBox' do
    pod 'JSONJoy-Swift', '~> 2.0.1'
    pod 'SwiftHTTP', '~> 2.0.0'
    pod 'KeychainAccess'
    pod 'Toaster', '~> 2.0'
    pod 'DTCoreText'
    pod 'Fabric'
    pod 'Crashlytics'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
