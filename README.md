# MenuBarLiveActivity

**MenuBarLiveActivity** is an open-source Swift package that rebuilds the *Live Activities* feature introduced in macOS 26 for any macOS app.
It integrates live information directly into the macOS menu bar and works out of the box without any external dependencies.

<img width="469" height="38" alt="MenuBarLiveActivity" src="https://github.com/user-attachments/assets/d416c489-e783-4ca0-969f-f62b3080fd58" />

## Features

- 🎛️ Show or hide the Live Activity at any time
- 📊 Determinate progress (downloads, timers, tasks …)
- 🔄 Indeterminate spinner mode
- 🎨 Animated tint color, label and width changes
- 🖥️ Native `NSStatusItem` integration
- 📦 Zero external dependencies – pure AppKit

## Requirements

- macOS 14 or newer
- Swift 6.2 / Xcode 26

## Installation

### Swift Package Manager (Xcode)

1. In Xcode go to **File → Add Package Dependencies…**
2. Paste the repository URL:
   ```
   https://github.com/marcbuetti/MenuBarLiveActivity.git
   ```
3. Choose **Up to Next Major Version** starting at `1.0.0` and add the `MenuBarLiveActivity` library to your app target.

### Swift Package Manager (`Package.swift`)

```swift
dependencies: [
    .package(url: "https://github.com/marcbuetti/MenuBarLiveActivity.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["MenuBarLiveActivity"]
    )
]
```

## Usage

```swift
import AppKit
import SwiftUI
import MenuBarLiveActivity

@main
struct MyApp: App {

    private let activity: MenuBarLiveActivity

    init() {
        let icon = NSImage(systemSymbolName: "livephoto", accessibilityDescription: nil)!
        self.activity = MenuBarLiveActivity(icon: icon)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(activity: activity)
        }
    }
}
```

Drive the activity through its public API:

```swift
activity.setVisible(true)              // show / hide
activity.setName("Downloading…")       // update label (animates width)
activity.setProgress(0.42)             // 0.0 … 1.0
activity.setIndeterminate(true)        // spinner mode
activity.setTintColor(.systemGreen)    // animated color change
```

### Custom style

```swift
let style = MenuBarLiveActivity.Style(
    tintColor: .systemIndigo,
    textColor: .white,
    font: .systemFont(ofSize: 13, weight: .semibold)
)

let activity = MenuBarLiveActivity(icon: icon, style: style)
```

## Demo

A complete SwiftUI demo app is included in the `Demo/` folder of this repository.
Open `Demo/MenuBarLiveActivityDemo.xcodeproj` in Xcode and run the `MenuBarLiveActivityDemo` scheme.

## License

Released under the MIT License.
