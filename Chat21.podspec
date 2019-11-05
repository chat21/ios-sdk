Pod::Spec.new do |s|

s.platform = :ios
s.ios.deployment_target = '10.0'
s.name = "Chat21"
s.summary = "Chat21 adds instant messaging to your iOS App."

s.description  = <<-DESC
Chat21 allows your users to easily communicate with each other. Chat21 iOS SDK adds instant messaging to your App. Swift and Objc supported.
                   DESC

s.requires_arc = true

s.version = "0.8.52"

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

s.resources = "Resources/**/*.{png,jpeg,jpg,storyboard,xib,xcassets,caf,plist,lproj}"

s.public_header_files = 'Chat21/**/*.h'

end
