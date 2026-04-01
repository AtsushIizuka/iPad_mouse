import ApplicationServices
import Foundation
import AppKit

@MainActor
final class AccessibilityPermissionManager {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestPermissionPrompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
            NSWorkspace.shared.open(url)
        else {
            return
        }
    }
}
