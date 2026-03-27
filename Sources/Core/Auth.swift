import Foundation
import LocalAuthentication

enum Auth {
    static func requireTouchID(reason: String) throws {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            throw AuthError.unavailable(policyError?.localizedDescription ?? "unknown")
        }

        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var authError: Error?

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            if !success {
                authError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = authError {
            throw AuthError.denied(error.localizedDescription)
        }
    }
}

enum AuthError: Error, CustomStringConvertible {
    case unavailable(String)
    case denied(String)

    var description: String {
        switch self {
        case .unavailable(let reason): "Touch ID not available: \(reason)"
        case .denied(let reason):      "Authentication failed: \(reason)"
        }
    }
}
