import Foundation
import LocalAuthentication

/// Optional Face ID / passcode lock for the whole app.
@MainActor
final class AppLock: ObservableObject {
    nonisolated static let enabledKey = "requireFaceID"

    @Published private(set) var isLocked: Bool
    @Published var errorMessage: String?
    private var isAuthenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    func unlock() {
        guard isLocked, !isAuthenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode or biometrics on this device: never lock people out of their data.
            isLocked = false
            return
        }
        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your health data") { success, authError in
            Task { @MainActor in
                self.isAuthenticating = false
                if success {
                    self.isLocked = false
                    self.errorMessage = nil
                } else {
                    self.errorMessage = authError?.localizedDescription
                }
            }
        }
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Passcode"
        }
    }
}
