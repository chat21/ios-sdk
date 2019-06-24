# Chat21 APIs for iOS

Simplify adding Instant Messaging features to your app with Chat21 SDK.

Much more information can be found at [http://www.chat21.org](http://www.chat21.org).

## Install Chat21 SDK using CocoaPods

Chat21 is distributed via CocoaPods.
You can install the CocoaPods tool on OS X by running the following command from
the terminal. Detailed information is available in the [Getting Started
guide](https://guides.cocoapods.org/using/getting-started.html#getting-started).

```
$ sudo gem install cocoapods
```

Note that Chat21 SDK require a Firebase Project to work. More information about the creation of a Firebase project is available at [https://firebase.google.com/docs/](https://firebase.google.com/docs/).

## Add Chat21 SDK to your iOS app

CocoaPods is used to install and manage dependencies in existing Xcode projects.

1.  Create an Xcode project, and save it to your local machine.
2.  Create a file named `Podfile` in your project directory. This file defines
    your project's dependencies, and is commonly referred to as a Podspec.
3.  Open `Podfile`, and add your dependencies. A simple Podspec is shown here:

    ```
    platform :ios, '8.0'
    pod 'Chat21'
    ```

4.  Save the file.

5.  Open a terminal and `cd` to the directory containing the Podfile.

    ```
    $ cd <path-to-project>/project/
    ```

6.  Run the `pod install` command. This will install the SDKs specified in the
    Podspec, along with any dependencies they may have.

    ```
    $ pod install
    ```

7.  Open your app's `.xcworkspace` file to launch Xcode. Use this file for all
    development on your app.

