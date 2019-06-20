Pod::Spec.new do |s|

s.platform = :ios
s.ios.deployment_target = '10.0'
s.name = "Chat21"
s.summary = "Chat21 lets you add instant messaging to your iOS App."
s.requires_arc = true

s.version = "0.8.19"

s.license = { :type => "MIT", :file => "LICENSE" }

s.author = { "Andrea Sponziello" => "andreasponziello@gmail.com" }

s.homepage = "http://www.chat21.org"

s.source = { :git => "https://github.com/chat21/ios-sdk.git", :tag => "#{s.version}" }

s.static_framework = true
s.dependency 'SVProgressHUD'
s.dependency 'NYTPhotoViewer'
s.dependency 'KeychainItemWrapper'
s.dependency 'Firebase/Core'
s.dependency 'Firebase/Database'
s.dependency 'Firebase/Auth'
s.dependency 'Firebase/Messaging'
s.dependency 'Firebase/Storage'

s.source_files  = "Chat21/**/*.{h,m}"

# MOVES FILES IN RESOURCES FOLDER - IN POD'S ROOT FOLDER
s.resources = "Chat21/**/*.{png,jpeg,jpg,storyboard,xib,xcassets}"
# s.resource_bundle = { 'Resources' => 'Chat21/**/*.{lproj}' }
s.ios.resource_bundle = { 'MapBox' => 'Resources/**/*.strings' }

s.public_header_files = 'Chat21/**/*.h'

end
