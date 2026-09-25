import Combine
import Foundation
import UIKit

// MARK: - Comfort settings
//
// Mirrors the web's Comfort section: larger text and reduced motion are stored
// on this device only and never leave it. DesignTokens.text/display read the
// shared instance so the type ramp scales app-wide.

final class A11ySettings: ObservableObject {
    static let shared = A11ySettings()

    private static let largeTextKey = "verbalibera.a11y.largeText"
    private static let reduceMotionKey = "verbalibera.a11y.reduceMotion"

    /// Extra type scale applied by DesignTokens when enabled.
    static let largeTextScale: CGFloat = 1.25

    @Published var largeText: Bool = UserDefaults.standard.bool(
        forKey: largeTextKey
    ) {
        didSet {
            UserDefaults.standard.set(
                largeText, forKey: Self.largeTextKey)
        }
    }

    @Published var reduceMotion: Bool = UserDefaults.standard.bool(
        forKey: reduceMotionKey
    ) {
        didSet {
            UserDefaults.standard.set(
                reduceMotion, forKey: Self.reduceMotionKey)
        }
    }

    /// The in-app toggle or the system setting — either one disables
    /// animation app-wide (applied as a root transaction in ContentView).
    var effectiveReduceMotion: Bool {
        reduceMotion || UIAccessibility.isReduceMotionEnabled
    }

    private var motionObserver: NSObjectProtocol?

    private init() {
        motionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
