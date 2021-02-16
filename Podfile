# Uncomment this line to define a global platform for your project
platform :osx, '10.13'

inhibit_all_warnings!

source 'https://github.com/CocoaPods/Specs.git'

project 'Hammerspoon', 'Profile' => :debug

target 'Hammerspoon' do
pod 'ASCIImage'
pod 'CocoaLumberjack'
pod 'CocoaAsyncSocket'
pod 'CocoaHTTPServer', :git => 'https://github.com/CommandPost/CocoaHTTPServer.git'
pod 'PocketSocket/Client'
pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
pod 'Sparkle', :configurations => ['Release']
pod 'MIKMIDI'
pod 'ORSSerialPort'
pod 'SocketRocket'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
   puts "Enabling assertions in #{target.name}"
   target.build_configurations.each do |config|
     config.build_settings['ENABLE_NS_ASSERTIONS'] = 'YES'
     if ['10.6', '10.7', '10.8'].include? config.build_settings['MACOSX_DEPLOYMENT_TARGET']
       config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
     end
   end
  end
end
