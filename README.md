# ios-sdk

## Add Chat21 libs to the project

Create a file named “Podfile” in the project’s root folder with the following content:
<pre>
<code>
    
    platform :ios, '10.0'
    
    target 'MyChat' do
    pod 'Chat21'
    end

</code>
</pre>

Close Xcode and run:

> **pod install**

From now on open the project using _MyChat.xcworkspace_ file.