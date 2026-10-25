//
//  ContentView.swift
//  MenuBarLiveActivityDemo
//
//  Created by Marc Büttner on 09.09.25.
//

import SwiftUI
import MenuBarLiveActivity

struct ContentView: View {

    let activity: MenuBarLiveActivity

    @State private var progress: Double = 0.0
    @State private var isVisible: Bool = false
    @State private var name: String = "Updating Software"
    @State private var isIndeterminate: Bool = false
    @State private var tintColor: Color = Color(nsColor: .systemBlue)
    @State private var useGlass: Bool = false
    @State private var indicator: Indicator = .progressRing
    @State private var symbolColor: Color = .white
    @State private var rendering: Rendering = .monochrome

    /// SF Symbols rendering modes offered in the demo.
    private enum Rendering: String, CaseIterable, Identifiable {
        case monochrome, hierarchical, multicolor

        var id: Self { self }

        var title: String {
            switch self {
            case .monochrome: "Monochrome"
            case .hierarchical: "Hierarchical"
            case .multicolor: "Multicolor"
            }
        }

        /// Multicolor ignores the colour picker entirely.
        var usesColor: Bool { self != .multicolor }

        func symbolRendering(with color: NSColor) -> MenuBarLiveActivity.SymbolRendering {
            switch self {
            case .monochrome: .monochrome(color)
            case .hierarchical: .hierarchical(color)
            case .multicolor: .multicolor
            }
        }
    }

    /// What is shown in the indicator slot of the pill.
    private enum Indicator: String, CaseIterable, Identifiable {
        case progressRing
        case downloading
        case success
        case warning

        var id: Self { self }

        /// SF Symbol name, or `nil` for the progress ring.
        var symbolName: String? {
            switch self {
            case .progressRing: nil
            case .downloading: "arrow.down.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            }
        }

        /// Picker label: the real SF Symbol name so it's obvious what is used.
        var title: String {
            symbolName ?? "Progress Ring"
        }

        /// Spoken description for VoiceOver.
        var accessibilityDescription: String {
            switch self {
            case .progressRing: "Progress"
            case .downloading: "Downloading"
            case .success: "Success"
            case .warning: "Warning"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("MenuBarLiveActivity Controller")
                .font(.title3).bold()
                .frame(maxWidth: .infinity, alignment: .center)

            Toggle("Show Live Activity", isOn: $isVisible)
                .onChange(of: isVisible) { _, value in
                    activity.setVisible(value)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, value in
                        activity.setName(value)
                    }
            }

            ColorPicker("Tint Color", selection: $tintColor, supportsOpacity: false)
                .onChange(of: tintColor) { _, value in
                    activity.setTintColor(NSColor(value))
                }

            Toggle("Animated (indeterminate)", isOn: $isIndeterminate)
                .onChange(of: isIndeterminate) { _, value in
                    activity.setIndeterminate(value)
                }

            Toggle("Liquid Glass Background", isOn: $useGlass)
                .onChange(of: useGlass) { _, value in
                    activity.setGlassBackground(value)
                }

            VStack(alignment: .leading, spacing: 4) {
                Picker("Indicator (SF Symbol)", selection: $indicator) {
                    ForEach(Indicator.allCases) { indicator in
                        if let symbolName = indicator.symbolName {
                            Label(symbolName, systemImage: symbolName).tag(indicator)
                        } else {
                            Text(indicator.title).tag(indicator)
                        }
                    }
                }
                .onChange(of: indicator) { _, _ in
                    applyIndicator()
                }
                if let symbolName = indicator.symbolName {
                    Text("Using SF Symbol \"\(symbolName)\"")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Symbol Rendering", selection: $rendering) {
                ForEach(Rendering.allCases) { rendering in
                    Text(rendering.title).tag(rendering)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: rendering) { _, _ in
                applyIndicator()
            }
            .disabled(indicator == .progressRing)

            ColorPicker("Symbol Color", selection: $symbolColor, supportsOpacity: false)
                .onChange(of: symbolColor) { _, _ in
                    applyIndicator()
                }
                .disabled(indicator == .progressRing || !rendering.usesColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("Progress: \(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Slider(value: $progress, in: 0...1, step: 0.01)
                    .onChange(of: progress) { _, value in
                        activity.setProgress(value)
                    }
                    .disabled(isIndeterminate)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    /// Pushes the selected indicator and symbol colour to the activity.
    private func applyIndicator() {
        if let symbolName = indicator.symbolName {
            activity.setSymbol(
                systemName: symbolName,
                accessibilityDescription: indicator.accessibilityDescription,
                rendering: rendering.symbolRendering(with: NSColor(symbolColor))
            )
        } else {
            activity.setSymbol(nil)
        }
    }
}
