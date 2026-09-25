import AuthenticationServices
import Foundation
import Security
import SwiftUI
import UIKit

// MARK: - Keychain

/// Minimal generic-password keychain storage for the Apple user identifier.
/// The identifier is a stable, opaque user key — it lives in the keychain,
/// never in UserDefaults or logs.
enum Keychain {
    static func set(_ value: String, service: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        _ = SecItemAdd(add as CFDictionary, nil)
    }

    static func get(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth state

/// Sign in with Apple identity. Practice never requires an account; signing
/// in marks this device's progress as belonging to the learner's account so
/// sync can carry it to their other devices.
@MainActor
final class AuthState: ObservableObject {
    private static let service = "com.sleuthysloth.verbalibera"
    private static let userIdAccount = "appleUserId"
    private static let displayNameKey = "verbalibera.appleDisplayName"

    @Published private(set) var userId: String?
    @Published private(set) var displayName: String?

    var isSignedIn: Bool { userId != nil }

    init() {
        userId = Keychain.get(
            service: Self.service, account: Self.userIdAccount)
        displayName = UserDefaults.standard.string(forKey: Self.displayNameKey)
        if userId != nil {
            Task { await self.verifyCredential() }
        }
    }

    /// Called with the credential from a successful Sign in with Apple flow.
    func didSignIn(credential: ASAuthorizationAppleIDCredential) {
        Keychain.set(
            credential.user, service: Self.service,
            account: Self.userIdAccount)
        userId = credential.user
        // Full name and email are only provided on the first authorization.
        var name: String?
        if let components = credential.fullName {
            let formatted = PersonNameComponentsFormatter().string(
                from: components)
            if !formatted.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty
            {
                name = formatted
            }
        }
        if name == nil, let email = credential.email, !email.isEmpty {
            name = email
        }
        if let name {
            UserDefaults.standard.set(name, forKey: Self.displayNameKey)
            displayName = name
        }
    }

    /// Signs out on this device. Local progress stays put — signing out only
    /// stops syncing; it never deletes the learner's work.
    func signOut() {
        Keychain.delete(
            service: Self.service, account: Self.userIdAccount)
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        userId = nil
        displayName = nil
    }

    /// If Apple reports the credential revoked or unknown, drop the local
    /// session. Network failures keep the current state.
    private func verifyCredential() async {
        guard let userId else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<
                    ASAuthorizationAppleIDProvider.CredentialState, Error
                >) in
                provider.getCredentialState(forUserID: userId) { state, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: state)
                    }
                }
            }
        } catch {
            return
        }
        if state == .revoked || state == .notFound {
            signOut()
        }
    }
}

// MARK: - Sign in with Apple button

/// Wraps ASAuthorizationAppleIDButton. Tapping starts the authorization flow;
/// the result comes back through the coordinator's delegate callbacks.
struct SignInWithAppleButton: UIViewRepresentable {
    var onCredential: (ASAuthorizationAppleIDCredential) -> Void
    var onError: (Error) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            type: .signIn, style: .black)
        button.cornerRadius = 12
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTapButton),
            for: .touchUpInside)
        return button
    }

    func updateUIView(
        _ uiView: ASAuthorizationAppleIDButton, context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCredential: onCredential, onError: onError)
    }

    final class Coordinator: NSObject,
        ASAuthorizationControllerDelegate,
        ASAuthorizationControllerPresentationContextProviding
    {
        let onCredential: (ASAuthorizationAppleIDCredential) -> Void
        let onError: (Error) -> Void

        init(
            onCredential: @escaping (ASAuthorizationAppleIDCredential) -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onCredential = onCredential
            self.onError = onError
        }

        @objc func didTapButton() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(
                authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            guard let credential = authorization.credential
                as? ASAuthorizationAppleIDCredential
            else { return }
            onCredential(credential)
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            onError(error)
        }

        func presentationAnchor(
            for controller: ASAuthorizationController
        ) -> ASPresentationAnchor {
            if let scene = UIApplication.shared.connectedScenes.first
                as? UIWindowScene,
               let window = scene.windows.first(where: {
                   $0.isKeyWindow
               })
            {
                return window
            }
            return UIWindow()
        }
    }
}
