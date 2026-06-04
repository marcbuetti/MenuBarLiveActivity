//
//  MenuBarLiveActivity.swift
//  MenuBarLiveActivity
//

import AppKit

/// A pill-shaped "live activity" view rendered inside an `NSStatusItem`.
///
/// Configure the activity with an icon and an optional menu, then drive its
/// state through ``setVisible(_:)``, ``setProgress(_:)``, ``setName(_:)``,
/// ``setIndeterminate(_:)`` and ``setTintColor(_:)``. While visible the
/// pill replaces the status item's icon and is sized to fit the current
/// name; updates to the name animate the pill's width in place. Showing
/// and hiding use an Apple-style scale + opacity transition that mimics
/// the system Live Activity reveal.
///
/// All public API is main-actor isolated and must be called on the main thread.
@MainActor
public final class MenuBarLiveActivity {

    /// Visual and timing configuration for a ``MenuBarLiveActivity``.
    ///
    /// Pass a customised `Style` to the initializer to change colours, font
    /// or animation durations. All values have sensible defaults that
    /// match the system menu bar look.
    public struct Style {
        /// Background colour of the pill.
        public let tintColor: NSColor
        /// Colour used for the title text and the progress ring.
        public let textColor: NSColor
        /// Font of the title label.
        public let font: NSFont
        /// Duration of the animation when the determinate progress value changes.
        public let progressAnimationDuration: TimeInterval
        /// Duration of the animation when the pill's width changes because the
        /// name was updated.
        public let widthAnimationDuration: TimeInterval
        /// Duration of the colour-crossfade triggered by ``setTintColor(_:)``.
        public let tintAnimationDuration: TimeInterval
        /// Duration of the scale + opacity transition used when the pill is
        /// shown or hidden.
        public let showHideAnimationDuration: TimeInterval
        /// Time it takes the indeterminate spinner to complete one full revolution.
        public let indeterminateRotationDuration: TimeInterval
        /// Fraction of the progress arc that is drawn while in indeterminate
        /// mode (`0.0`–`1.0`). The visible segment rotates around the ring.
        public let indeterminateArcLength: CGFloat

        /// Creates a style. Every parameter has a default; override only what
        /// you want to change.
        public init(
            tintColor: NSColor = .systemBlue,
            textColor: NSColor = .white,
            font: NSFont = .systemFont(ofSize: 13, weight: .semibold),
            progressAnimationDuration: TimeInterval = 0.3,
            widthAnimationDuration: TimeInterval = 0.25,
            tintAnimationDuration: TimeInterval = 0.3,
            showHideAnimationDuration: TimeInterval = 0.3,
            indeterminateRotationDuration: TimeInterval = 1.0,
            indeterminateArcLength: CGFloat = 0.25
        ) {
            self.tintColor = tintColor
            self.textColor = textColor
            self.font = font
            self.progressAnimationDuration = progressAnimationDuration
            self.widthAnimationDuration = widthAnimationDuration
            self.tintAnimationDuration = tintAnimationDuration
            self.showHideAnimationDuration = showHideAnimationDuration
            self.indeterminateRotationDuration = indeterminateRotationDuration
            self.indeterminateArcLength = indeterminateArcLength
        }
    }

    private let statusItem: NSStatusItem
    private let style: Style

    private var pillContainer: NSView?
    private var progressLayer: CAShapeLayer?
    private var trackLayer: CAShapeLayer?
    private var titleLabel: NSTextField?
    private var widthConstraint: NSLayoutConstraint?
    private var hideTask: Task<Void, Never>?

    private let widthLinkProxy = DisplayLinkProxy()
    private var widthDisplayLink: CADisplayLink?
    private var widthAnimStartTime: CFTimeInterval = 0
    private var widthAnimStartWidth: CGFloat = 0
    private var widthAnimEndWidth: CGFloat = 0
    private var widthAnimDuration: TimeInterval = 0

    private var isVisible: Bool = false
    private var progressValue: CGFloat = 0
    private var name: String
    private var isIndeterminate: Bool = false
    private var currentTintColor: NSColor

    private let pillHeight: CGFloat = 24
    private let leftPadding: CGFloat = 6
    private let rightPadding: CGFloat = 12
    private let spacing: CGFloat = 8
    private let indicatorDiameter: CGFloat = 20
    private let indicatorLineWidth: CGFloat = 3.5

    private var savedImage: NSImage?
    private var savedTitle: String = ""
    // Original `statusItem.length` value (typically a sentinel like
    // `variableLength`) so we can hand the click-target's width back to the
    // system as soon as the pill is gone.
    private var savedLength: CGFloat = NSStatusItem.variableLength
    // The button's default bezel paints a rectangular highlight in the
    // wider click target while the pill is still partially transparent.
    // We disable it during pill display and restore the original value on
    // hide so we don't change behaviour for callers that customise it.
    private var savedIsBordered: Bool = true
    // `isTransparent` stops the button from drawing anything at all (cell
    // background, focus ring, hover state) while still forwarding mouse
    // events to the menu. We toggle it on for the pill display and back to
    // the original value on hide.
    private var savedIsTransparent: Bool = false

    /// Creates a live activity that drives an existing `NSStatusItem`.
    ///
    /// Use this initializer when you already own the status item, for example
    /// because you need to keep a reference to it for other purposes. The
    /// `icon` and `menu` arguments are convenience hooks that simply forward
    /// to `statusItem.button?.image` and `statusItem.menu` respectively — if
    /// you've already configured those on the status item you can leave them `nil`.
    ///
    /// - Parameters:
    ///   - statusItem: The status item the pill should attach to.
    ///   - icon: Optional icon applied to the status item's button.
    ///   - menu: Optional menu attached to the status item. The menu remains
    ///     available while the pill is visible — clicking the pill opens it.
    ///   - name: Initial title shown next to the progress ring.
    ///   - style: Visual / timing configuration. Defaults to system blue at the
    ///     system menu-bar font size.
    public init(
        statusItem: NSStatusItem,
        icon: NSImage? = nil,
        menu: NSMenu? = nil,
        name: String = "Updating Software",
        style: Style = Style()
    ) {
        self.statusItem = statusItem
        self.name = name
        self.style = style
        self.currentTintColor = style.tintColor
        self.widthLinkProxy.callback = { [weak self] in
            self?.tickWidthAnimation()
        }
        if let icon {
            statusItem.button?.image = icon
        }
        if let menu {
            statusItem.menu = menu
        }
    }

    /// Creates a live activity and the `NSStatusItem` it lives in.
    ///
    /// The most common entry point: pass the icon and (optionally) the menu
    /// you'd normally configure on a status item and the activity will create
    /// the status item for you. While the pill is visible the icon is swapped
    /// out and replaced with the pill; the menu stays attached, so clicking
    /// the pill still opens it.
    ///
    /// - Parameters:
    ///   - icon: Icon shown in the menu bar while the activity is hidden.
    ///   - menu: Optional menu attached to the status item.
    ///   - name: Initial title shown next to the progress ring.
    ///   - style: Visual / timing configuration.
    public convenience init(
        icon: NSImage,
        menu: NSMenu? = nil,
        name: String = "Updating Software",
        style: Style = Style()
    ) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.init(statusItem: item, icon: icon, menu: menu, name: name, style: style)
    }

    /// Shows or hides the pill.
    ///
    /// Transitions are animated using ``Style/showHideAnimationDuration``.
    /// Calling this with the current value is a no-op. Calling it while a
    /// previous transition is still running cancels and reverses smoothly,
    /// so it's safe to bind directly to a SwiftUI `Toggle`.
    public func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        if visible {
            showPillView()
        } else {
            hidePillView()
        }
    }

    /// Sets the determinate progress value in `0.0…1.0`.
    ///
    /// Values outside the range are clamped. The progress ring animates from
    /// its current value over ``Style/progressAnimationDuration``. Calls made
    /// while ``setIndeterminate(_:)`` is `true` are stored but not drawn until
    /// indeterminate mode is turned off.
    public func setProgress(_ value: Double) {
        let clamped = CGFloat(max(0.0, min(1.0, value)))
        progressValue = clamped
        guard isVisible, !isIndeterminate else { return }
        if progressLayer == nil { showPillView() }
        animateStrokeEnd(to: clamped)
    }

    /// Updates the title shown next to the progress ring.
    ///
    /// If the pill is visible the label is updated in place and the pill width
    /// animates smoothly to fit the new text — there is no rebuild and no jump.
    public func setName(_ name: String) {
        self.name = name
        guard
            isVisible,
            let label = titleLabel,
            pillContainer != nil
        else { return }

        label.stringValue = name
        label.sizeToFit()
        label.frame = NSRect(
            x: leftPadding + indicatorDiameter + spacing,
            y: (pillHeight - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )

        let newPillWidth = leftPadding + indicatorDiameter + spacing + label.frame.width + rightPadding
        animatePillWidth(to: newPillWidth)
    }

    /// Changes the pill's tint colour and animates the crossfade.
    ///
    /// The new colour is remembered, so subsequent show / hide cycles use it
    /// as well. Pass any `NSColor`; `Color` values from SwiftUI can be bridged
    /// with `NSColor(_:)`.
    public func setTintColor(_ color: NSColor) {
        currentTintColor = color
        guard
            isVisible,
            let layer = pillContainer?.layer
        else { return }

        let from = layer.presentation()?.backgroundColor ?? layer.backgroundColor
        let to = color.cgColor
        layer.removeAnimation(forKey: "backgroundColor")
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = style.tintAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.backgroundColor = to
        layer.add(animation, forKey: "backgroundColor")
    }

    /// Switches the progress ring between a determinate value and an
    /// indeterminate spinning arc.
    ///
    /// In indeterminate mode the ring shows a partial arc
    /// (``Style/indeterminateArcLength``) that rotates around the centre.
    /// The most recent value passed to ``setProgress(_:)`` is retained and
    /// restored when indeterminate mode is turned off.
    public func setIndeterminate(_ indeterminate: Bool) {
        guard isIndeterminate != indeterminate else { return }
        isIndeterminate = indeterminate
        guard isVisible, let layer = progressLayer else { return }
        if indeterminate {
            startSpin(on: layer)
        } else {
            stopSpin(on: layer)
        }
    }

    // MARK: - Internal

    private func saveOriginalStateIfNeeded() {
        guard pillContainer == nil, let button = statusItem.button else { return }
        savedImage = button.image
        savedTitle = button.title
        savedLength = statusItem.length
        savedIsBordered = button.isBordered
        savedIsTransparent = button.isTransparent
    }

    private func restoreIcon() {
        widthDisplayLink?.invalidate()
        widthDisplayLink = nil
        hideTask?.cancel()
        hideTask = nil

        guard let button = statusItem.button else { return }
        button.subviews.forEach { $0.removeFromSuperview() }
        button.image = savedImage
        button.title = savedTitle
        button.isBordered = savedIsBordered
        button.isTransparent = savedIsTransparent
        statusItem.length = savedLength

        pillContainer = nil
        progressLayer = nil
        trackLayer = nil
        titleLabel = nil
        widthConstraint = nil
    }

    private func showPillView() {
        guard let button = statusItem.button else { return }
        widthDisplayLink?.invalidate()
        widthDisplayLink = nil
        hideTask?.cancel()
        hideTask = nil

        // Caught mid-hide: the container is still attached but fading out.
        // Just reverse the transition back to fully visible instead of
        // rebuilding.
        if pillContainer != nil {
            transitionPill(visible: true)
            return
        }

        saveOriginalStateIfNeeded()

        let label = NSTextField(labelWithString: name)
        label.backgroundColor = .clear
        label.textColor = style.textColor
        label.font = style.font
        label.alignment = .left
        label.sizeToFit()

        let pillWidth = leftPadding + indicatorDiameter + spacing + label.frame.width + rightPadding

        let container = NSView(frame: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTintColor.cgColor
        container.layer?.cornerRadius = pillHeight / 2
        container.layer?.masksToBounds = true
        container.alphaValue = 0

        let indicatorFrame = NSRect(
            x: leftPadding,
            y: (pillHeight - indicatorDiameter) / 2,
            width: indicatorDiameter,
            height: indicatorDiameter
        )
        let indicatorView = NSView(frame: indicatorFrame)
        indicatorView.wantsLayer = true

        let center = CGPoint(x: indicatorDiameter / 2, y: indicatorDiameter / 2)
        let radius = (indicatorDiameter - indicatorLineWidth) / 2
        let startAngle = CGFloat.pi
        let endAngle = startAngle - 2 * CGFloat.pi

        let path = CGMutablePath()
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: true)

        // Explicit bounds + centered anchor so the progress layer can rotate
        // around the indicator's middle during the indeterminate animation.
        let layerBounds = CGRect(x: 0, y: 0, width: indicatorDiameter, height: indicatorDiameter)

        let track = CAShapeLayer()
        track.path = path
        track.strokeColor = style.textColor.withAlphaComponent(0.28).cgColor
        track.fillColor = NSColor.clear.cgColor
        track.lineWidth = indicatorLineWidth
        track.bounds = layerBounds
        track.position = center
        track.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        indicatorView.layer?.addSublayer(track)

        let progress = CAShapeLayer()
        progress.path = path
        progress.strokeColor = style.textColor.cgColor
        progress.fillColor = NSColor.clear.cgColor
        progress.lineWidth = indicatorLineWidth
        progress.lineCap = .round
        progress.strokeStart = 0.0
        progress.strokeEnd = isIndeterminate ? style.indeterminateArcLength : progressValue
        progress.bounds = layerBounds
        progress.position = center
        progress.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        indicatorView.layer?.addSublayer(progress)

        label.frame = NSRect(
            x: indicatorFrame.maxX + spacing,
            y: (pillHeight - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )

        container.addSubview(indicatorView)
        container.addSubview(label)

        button.title = ""
        button.image = nil
        button.isBordered = false
        button.isTransparent = true
        button.subviews.forEach { $0.removeFromSuperview() }
        statusItem.length = pillWidth
        attachCentered(container, to: button, width: pillWidth, height: pillHeight)

        pillContainer = container
        progressLayer = progress
        trackLayer = track
        titleLabel = label

        if isIndeterminate {
            startSpin(on: progress)
        }

        // The click target snaps to its full width and the visible pill
        // pops in with a scale + opacity transition around its centre.
        container.alphaValue = 0
        container.layer?.transform = Self.centeredScale(Self.pillStartScale, in: container.bounds)
        transitionPill(visible: true)
    }

    private func hidePillView() {
        widthDisplayLink?.invalidate()
        widthDisplayLink = nil
        hideTask?.cancel()

        guard pillContainer != nil else {
            restoreIcon()
            return
        }

        let duration = style.showHideAnimationDuration
        transitionPill(visible: false)

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard !Task.isCancelled else { return }
            self?.restoreIcon()
        }
    }

    // Apple's "settle" easing curve: long, soft tail that mimics a
    // critically damped spring without overshoot. Used by many system
    // reveals (popovers, sheet pulls, dynamic island content swaps).
    private static let revealTimingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
    // Initial / collapsed scale for the show & hide transitions. Subtle
    // enough to feel like a gentle settle rather than an aggressive pop.
    private static let pillStartScale: CGFloat = 0.88

    /// Composes a transform that scales a layer around the centre of the
    /// given bounds, working around AppKit's bottom-left default anchor on
    /// layer-backed views.
    private static func centeredScale(_ scale: CGFloat, in bounds: CGRect) -> CATransform3D {
        let cx = bounds.midX
        let cy = bounds.midY
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, cx, cy, 0)
        t = CATransform3DScale(t, scale, scale, 1)
        t = CATransform3DTranslate(t, -cx, -cy, 0)
        return t
    }

    private func transitionPill(visible: Bool) {
        guard let container = pillContainer, let layer = container.layer else { return }

        let duration = style.showHideAnimationDuration
        let targetScale: CGFloat = visible ? 1.0 : Self.pillStartScale
        let targetOpacity: Float = visible ? 1.0 : 0.0
        let targetTransform = Self.centeredScale(targetScale, in: layer.bounds)

        // Capture current presentation values so a mid-flight reversal
        // animates from where we visually are now, not from the model's
        // (final) value.
        let presentation = layer.presentation()
        let fromTransform = presentation?.transform ?? layer.transform
        let fromOpacity = presentation?.opacity ?? layer.opacity

        layer.removeAnimation(forKey: "pill.transform")
        layer.removeAnimation(forKey: "pill.opacity")

        layer.transform = targetTransform
        layer.opacity = targetOpacity
        container.alphaValue = CGFloat(targetOpacity)

        let scaleAnim = CABasicAnimation(keyPath: "transform")
        scaleAnim.fromValue = NSValue(caTransform3D: fromTransform)
        scaleAnim.toValue = NSValue(caTransform3D: targetTransform)
        scaleAnim.duration = duration
        scaleAnim.timingFunction = Self.revealTimingFunction
        scaleAnim.fillMode = .both

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = fromOpacity
        opacityAnim.toValue = targetOpacity
        opacityAnim.duration = duration
        opacityAnim.timingFunction = Self.revealTimingFunction
        opacityAnim.fillMode = .both

        layer.add(scaleAnim, forKey: "pill.transform")
        layer.add(opacityAnim, forKey: "pill.opacity")
    }

    private func computedPillWidth() -> CGFloat {
        guard let label = titleLabel else { return 0 }
        return leftPadding + indicatorDiameter + spacing + label.frame.width + rightPadding
    }

    private func attachCentered(_ view: NSView, to button: NSStatusBarButton, width: CGFloat, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(view)
        let widthConst = view.widthAnchor.constraint(equalToConstant: width)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            widthConst,
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        widthConstraint = widthConst
    }

    private func animatePillWidth(to newWidth: CGFloat, duration: TimeInterval? = nil) {
        widthDisplayLink?.invalidate()
        widthDisplayLink = nil

        let startWidth = statusItem.length
        let actualDuration = duration ?? style.widthAnimationDuration

        guard actualDuration > 0, abs(newWidth - startWidth) > 0.5 else {
            statusItem.length = newWidth
            widthConstraint?.constant = newWidth
            return
        }

        widthAnimStartTime = CACurrentMediaTime()
        widthAnimStartWidth = startWidth
        widthAnimEndWidth = newWidth
        widthAnimDuration = actualDuration

        // On macOS CADisplayLink has to be vended by an NSView/NSWindow/NSScreen
        // so the runtime can keep it in sync with the display the view is on.
        guard let host = statusItem.button else {
            statusItem.length = newWidth
            widthConstraint?.constant = newWidth
            return
        }

        let link = host.displayLink(target: widthLinkProxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        widthDisplayLink = link
    }

    private func tickWidthAnimation() {
        let elapsed = CACurrentMediaTime() - widthAnimStartTime
        let t = min(elapsed / widthAnimDuration, 1.0)
        let eased = Self.easeOut(t)
        let w = widthAnimStartWidth + (widthAnimEndWidth - widthAnimStartWidth) * eased
        statusItem.length = w
        widthConstraint?.constant = w
        if t >= 1.0 {
            widthDisplayLink?.invalidate()
            widthDisplayLink = nil
        }
    }

    private static func easeOut(_ t: Double) -> Double {
        let inv = 1 - t
        return 1 - inv * inv * inv
    }

    private func animateStrokeEnd(to value: CGFloat) {
        guard let layer = progressLayer else { return }
        let from = layer.presentation()?.strokeEnd ?? layer.strokeEnd
        layer.removeAnimation(forKey: "strokeEnd")
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = from
        animation.toValue = value
        animation.duration = style.progressAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.strokeEnd = value
        layer.add(animation, forKey: "strokeEnd")
    }

    private func startSpin(on layer: CAShapeLayer) {
        // Shrink the arc to a spinner segment and rotate the layer
        // continuously. The track is a full circle so its appearance is
        // unaffected — only the partial progress arc visibly spins.
        layer.removeAnimation(forKey: "strokeEnd")
        layer.strokeEnd = style.indeterminateArcLength

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = -CGFloat.pi * 2
        rotation.duration = style.indeterminateRotationDuration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        layer.add(rotation, forKey: "spin")
    }

    private func stopSpin(on layer: CAShapeLayer) {
        layer.removeAnimation(forKey: "spin")
        animateStrokeEnd(to: progressValue)
    }
}

/// NSObject shim so we can vend an `@objc` selector to `CADisplayLink`
/// without requiring `MenuBarLiveActivity` itself to inherit from NSObject.
@MainActor
private final class DisplayLinkProxy: NSObject {
    var callback: (@MainActor () -> Void)?

    @objc func tick() {
        callback?()
    }
}
