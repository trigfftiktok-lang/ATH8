import Combine
import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String?
    @Published private(set) var lastVerifiedAt: Date?
    @Published private(set) var licenseStatus = "Not verified"
    @Published var rememberKey = true

    private let service = "com.m3sb.external-ios.activation"
    private let keyAccount = "license-key"
    private let expiryAccount = "license-expiry"
    private let verifiedAccount = "license-verified-at"
    private let statusAccount = "license-status"
    private var lastAttemptAt: Date?
    private var verificationTask: URLSessionTask?

    init() {
        restoreCachedActivation()
        if let saved = rememberedKey() {
            // Keep the last known-good screen visible while the server rechecks the key.
            verifyOnServer(key: saved, saveKey: false)
        }
    }

    func beginLaunchSession() {
        guard !isBusy else { return }
        guard let saved = rememberedKey() else {
            isActive = false
            expirationDate = nil
            licenseStatus = "Key required"
            message = "Key required — enter your access key"
            return
        }
        verifyOnServer(key: saved, saveKey: false)
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Please wait a moment before trying again"
            return
        }
        lastAttemptAt = Date()
        verifyOnServer(key: trimmed, saveKey: rememberKey)
    }

    func rememberedKey() -> String? { string(for: keyAccount) }

    func refresh() { beginLaunchSession() }

    func deactivate() {
        verificationTask?.cancel()
        delete(keyAccount)
        delete(expiryAccount)
        delete(verifiedAccount)
        delete(statusAccount)
        isActive = false
        expirationDate = nil
        lastVerifiedAt = nil
        licenseStatus = "Not activated"
        message = "Activation removed from this device"
    }

    private func restoreCachedActivation() {
        guard rememberedKey() != nil else { return }
        expirationDate = date(for: expiryAccount)
        lastVerifiedAt = date(for: verifiedAccount)
        licenseStatus = string(for: statusAccount) ?? "Cached"

        // A non-expiring key or a future expiry is safe to show while revalidation runs.
        // The server result below remains authoritative and can immediately revoke access.
        if let expirationDate {
            isActive = expirationDate > Date()
        } else {
            isActive = true
        }
        message = "Checking saved license…"
    }

    private func verifyOnServer(key: String, saveKey: Bool) {
        isBusy = true
        // Do not hide the main app while a previously verified key is being rechecked.
        if !isActive { message = "Checking access key…" }

        verificationTask = APONLicenseSDK.verify(licenseKey: key) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                self.verificationTask = nil

                switch result {
                case .success(let state):
                    guard state.isActive else {
                        self.isActive = false
                        self.expirationDate = nil
                        self.licenseStatus = state.status?.capitalized ?? "Inactive"
                        self.message = state.message ?? self.friendlyMessage(for: state.status)
                        self.contactOwner = nil
                        self.delete(self.expiryAccount)
                        self.delete(self.verifiedAccount)
                        self.save(self.licenseStatus, for: self.statusAccount)
                        return
                    }
                    if saveKey { self.save(key, for: self.keyAccount) }
                    self.isActive = true
                    self.expirationDate = state.expiresDate
                    self.lastVerifiedAt = Date()
                    self.licenseStatus = "Active"
                    self.saveDate(state.expiresDate, for: self.expiryAccount)
                    self.saveDate(self.lastVerifiedAt, for: self.verifiedAccount)
                    self.save(self.licenseStatus, for: self.statusAccount)
                    self.contactOwner = nil
                    self.message = state.message ?? "Activated successfully"

                case .failure(let error):
                    // Keep a still-valid cached activation during a temporary network error.
                    if let expiry = self.expirationDate, expiry <= Date() {
                        self.isActive = false
                        self.expirationDate = nil
                        self.licenseStatus = "Verification failed"
                    }
                    self.message = error.localizedDescription
                }
            }
        }
    }

    private func friendlyMessage(for status: String?) -> String {
        switch status {
        case "expired": return "License expired"
        case "banned": return "License banned"
        case "invalid": return "Invalid license key"
        default: return "License is not active"
        }
    }

    private func date(for account: String) -> Date? {
        guard let raw = string(for: account) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func saveDate(_ value: Date?, for account: String) {
        guard let value else { delete(account); return }
        save(ISO8601DateFormatter().string(from: value), for: account)
    }

    private func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
