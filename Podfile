# Uncomment this line to define a global platform for your project
platform :osx, '10.13'

inhibit_all_warnings!

source 'https://github.com/CocoaPods/Specs.git'

project 'Hammerspoon', 'Profile' => :debug

target 'Hammerspoon' do
pod 'ASCIImage', '1.0.0'
pod 'CocoaLumberjack', '3.5.3'
pod 'CocoaAsyncSocket', '7.6.4'
pod 'CocoaHTTPServer', :git => 'https://github.com/CommandPost/CocoaHTTPServer.git'
pod 'PocketSocket/Client', '1.0.1'
pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.0.8'
pod 'Sparkle', '1.24.0', :configurations => ['Release']
pod 'MIKMIDI', '1.7.1'
pod 'SocketRocket', '0.5.1'
pod 'ORSSerialPort', '2.1.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
   puts "Enabling assertions in #{target.name}"
   target.build_configurations.each do |config|
     config.build_settings['ENABLE_NS_ASSERTIONS'] = 'YES'
   end
  end
end
