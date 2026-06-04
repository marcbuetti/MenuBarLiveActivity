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
}
