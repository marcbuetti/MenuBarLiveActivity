# MenuBarLiveActivity

**MenuBarLiveActivity** is an open-source Swift package that rebuilds the *Live Activities* feature introduced in macOS 26 for any macOS app.
It integrates live information directly into the macOS menu bar and works out of the box without any external dependencies.

<img width="469" height="38" alt="MenuBarLiveActivity" src="https://github.com/user-attachments/assets/d416c489-e783-4ca0-969f-f62b3080fd58" />

## Features

- 🎛️ Show or hide the Live Activity at any time
- 📊 Determinate progress (downloads, timers, tasks …)
- 🔄 Indeterminate spinner mode
- ✅ SF Symbols in place of the ring (e.g. checkmark or warning) with animated transitions
- 🎨 Animated tint color, label and width changes
- 🫧 Optional Liquid Glass background (macOS 26+, interactive glass on macOS 27+)
- ♿️ VoiceOver support – name and progress are exposed while the pill is visible
- 🖥️ Native `NSStatusItem` integration
- 📦 Zero external dependencies – pure AppKit

## Requirements

- macOS 14 or newer
- Swift 6 / Xcode 26 or newer (tested with Xcode 27 and the macOS 27 SDK)

## Installation

### Swift Package Manager (Xcode)

1. In Xcode go to **File → Add Package Dependencies…**
2. Paste the repository URL:
   ```
   https://github.com/marcbuetti/MenuBarLiveActivity.git
   ```
3. Choose **Up to Next Major Version** starting at `2.2.0` and add the `MenuBarLiveActivity` library to your app target.

### Swift Package Manager (`Package.swift`)

```swift
dependencies: [
    .package(url: "https://github.com/marcbuetti/MenuBarLiveActivity.git", from: "2.2.0")
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
activity.setGlassBackground(true)      // Liquid Glass capsule (macOS 26+)
activity.setSymbol(systemName: "checkmark.circle.fill")   // symbol instead of the ring
activity.setSymbol(nil)                // back to the progress ring
```

### Symbols instead of the ring

The indicator slot can show an SF Symbol instead of the progress ring — useful to signal a state once the work is done or failed. Switching between the ring and a symbol crossfades and scales the indicator; switching from one symbol to another uses the system's symbol replace animation. Progress and indeterminate state are kept while a symbol is shown, so going back to the ring picks up where it left off.

```swift
// Update finished
activity.setSymbol(systemName: "checkmark.circle.fill", accessibilityDescription: "Finished")

// Update failed: warning sign in the symbol's own colours on a red pill
activity.setTintColor(.systemRed)
activity.setSymbol(systemName: "exclamationmark.triangle.fill",
                   accessibilityDescription: "Failed",
                   rendering: .multicolor)

// Any symbol image works, not just SF Symbols by name
activity.setSymbol(myImage, rendering: .monochrome(.systemYellow))
```

The `rendering` parameter mirrors the SF Symbols rendering modes:

| Mode | Effect |
| --- | --- |
| `.monochrome(color)` | Single colour, defaults to the style's text colour. Multi-layer symbols keep their cut-out glyph. |
| `.hierarchical(color)` | One base colour; the system derives lighter shades for secondary layers. |
| `.multicolor` | The symbol's built-in colours, e.g. yellow for `exclamationmark.triangle.fill`. Symbols without a multicolor variant fall back to monochrome. |

Symbols are rendered at `Style.symbolPointSize` / `Style.symbolWeight`; the default matches the ring's 20 pt diameter. The accessibility description of the image is exposed to VoiceOver while the symbol is visible.

### Liquid Glass

On macOS 26 and newer the pill can use a Liquid Glass capsule instead of the flat tint fill. The glass is tinted with the current tint color, and on macOS 27 it is marked as interactive so it responds visually to clicks like other glass-backed controls. On older systems the call is a no-op and the flat fill is used.

### Menu or custom window

Pass an `NSMenu` and clicking the pill opens it — this is the recommended setup. If you prefer to present your own window or popover instead of a menu, keep the status item's `menu` set to `nil` and, on macOS 27 and newer, adopt `NSStatusItem.expandedInterfaceDelegate` so the system can handle keyboard navigation and menu-bar tracking for your window. The activity only touches the status item's button and never interferes with that delegate.

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
