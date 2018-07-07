# Uncomment this line to define a global platform for your project
platform :osx, '10.10'

source 'https://github.com/CocoaPods/Specs.git'

project 'Hammerspoon', 'Profile' => :debug

target 'Hammerspoon' do
pod 'ASCIImage', '1.0.0'
pod 'CocoaLumberjack', '3.4.2'
pod 'CocoaAsyncSocket', '7.6.3'
pod 'CocoaHTTPServer', '2.3'
pod 'PocketSocket/Client', '1.0.1'
pod 'Crashlytics', '3.10.2'
pod 'Fabric', '1.7.7'
pod 'Sparkle', '1.19.0', :configurations => ['Release']
pod 'MIKMIDI', :git => 'https://github.com/mixedinkey-opensource/MIKMIDI.git', :commit => 'bc623e9'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
   puts "Enabling assertions in #{target.name}"
   target.build_configurations.each do |config|
     config.build_settings['ENABLE_NS_ASSERTIONS'] = 'YES'
   end
  end
end
