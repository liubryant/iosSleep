import Combine
import Foundation
import Security

struct SleepAppleMembershipStatus {
    let active: Bool
    let expiresAt: String?
    let productID: String?
}

struct SleepApplePurchaseVerification {
    let active: Bool
    let expiresAt: String?
    let productID: String?
    let guestAccessToken: String?
    let transactionAlreadyProcessed: Bool
}

private enum SleepMembershipEndpoint {
    static let baseURL = "https://www.cjym123.cn/im/bot/sleep/vip"
}

final class SleepMembershipService {
    static let shared = SleepMembershipService()

    func loadAppleMembership(token: String) async throws -> SleepAppleMembershipStatus {
        let json = try await makeRequest(path: "/apple/membership", token: token)
        let data = json["data"] as? [String: Any] ?? [:]
        return SleepAppleMembershipStatus(
            active: bool(data["appleActive"]) || bool(data["active"]),
            expiresAt: string(data["appleExpiresAt"]) ?? string(data["expiresAt"]),
            productID: string(data["appleProductId"])
        )
    }

    func verifyApplePurchase(
        token: String?,
        appleProductID: String,
        transactionID: String,
        jws: String
    ) async throws -> SleepApplePurchaseVerification {
        let body: [String: Any] = [
                "appleProductId": appleProductID,
                "transactionId": transactionID,
                "jws": jws,
                "platform": "ios",
                "bundleId": Bundle.main.bundleIdentifier ?? ""
            ]
        let json: [String: Any]
        do {
            json = try await makeRequest(path: "/apple/verify", method: "POST", token: token, body: body)
        } catch let error as NSError where token != nil && error.code == 401 {
            // 登录凭证过期不能阻断一笔已经完成的 Apple 支付；降级为游客验签，之后可重新登录同步。
            json = try await makeRequest(path: "/apple/verify", method: "POST", body: body)
        }
        let data = json["data"] as? [String: Any] ?? [:]
        return SleepApplePurchaseVerification(
            active: bool(data["appleActive"]) || bool(data["active"]),
            expiresAt: string(data["appleExpiresAt"]) ?? string(data["expiresAt"]),
            productID: string(data["appleProductId"]),
            guestAccessToken: string(data["guestAccessToken"]),
            transactionAlreadyProcessed: bool(data["transactionAlreadyProcessed"])
        )
    }

    func bindGuestMembership(userToken: String, guestToken: String) async throws -> SleepAppleMembershipStatus {
        let json = try await makeRequest(
            path: "/apple/bind",
            method: "POST",
            token: userToken,
            body: ["guestAccessToken": guestToken]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        return SleepAppleMembershipStatus(
            active: bool(data["appleActive"]) || bool(data["active"]),
            expiresAt: string(data["appleExpiresAt"]) ?? string(data["expiresAt"]),
            productID: string(data["appleProductId"])
        )
    }

    private func makeRequest(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: SleepMembershipEndpoint.baseURL + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = json["code"]
        let succeeded = (code as? Int == 0) || (code as? String == "0")
        guard (200..<300).contains(http.statusCode), succeeded else {
            let message = json["msg"] as? String
                ?? json["message"] as? String
                ?? "请求失败，请稍后重试"
            throw NSError(
                domain: "SleepMembershipService",
                code: code as? Int ?? http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        return json
    }

    private func string(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }
}

@MainActor
final class SleepMembershipSession: ObservableObject {
    static let shared = SleepMembershipSession()

    private enum Key {
        static let active = "sleep.vip.active"
        static let expiresAt = "sleep.vip.expiresAt"
        static let productID = "sleep.vip.productID"
    }

    private static let userTokenAccount = "sleep_user_access_token"
    private static let guestTokenAccount = "sleep_apple_guest_access_token"

    @Published private(set) var isVIPActive: Bool
    @Published private(set) var expiresAt: String?
    @Published private(set) var productID: String?

    private let defaults = UserDefaults.standard
    private let keychain = SleepKeychainStore()

    private init() {
        isVIPActive = defaults.bool(forKey: Key.active)
        expiresAt = defaults.string(forKey: Key.expiresAt)
        productID = defaults.string(forKey: Key.productID)
        if let expiresAt, Self.serverDate(from: expiresAt).map({ $0 <= Date() }) == true {
            isVIPActive = false
            self.expiresAt = nil
            productID = nil
            persist()
        }
    }

    var userAccessToken: String? {
        keychain.string(for: Self.userTokenAccount)
    }

    var guestAccessToken: String? {
        keychain.string(for: Self.guestTokenAccount)
    }

    var effectiveAccessToken: String? {
        if let userAccessToken, !userAccessToken.isEmpty { return userAccessToken }
        return guestAccessToken
    }

    func saveUserAccessToken(_ token: String) {
        try? keychain.setString(token, for: Self.userTokenAccount)
    }

    func apply(_ verification: SleepApplePurchaseVerification) {
        if let guestToken = verification.guestAccessToken {
            try? keychain.setString(guestToken, for: Self.guestTokenAccount)
        }
        update(active: verification.active, expiresAt: verification.expiresAt, productID: verification.productID)
    }

    func refresh() async throws {
        guard let token = effectiveAccessToken, !token.isEmpty else { return }
        let status: SleepAppleMembershipStatus
        do {
            let primary = try await SleepMembershipService.shared.loadAppleMembership(token: token)
            if primary.active || token == guestAccessToken || guestAccessToken == nil {
                status = primary
            } else if let guestAccessToken {
                status = try await SleepMembershipService.shared.loadAppleMembership(token: guestAccessToken)
            } else {
                status = primary
            }
        } catch let error as NSError where error.code == 401
            && token == userAccessToken && guestAccessToken != nil {
            status = try await SleepMembershipService.shared.loadAppleMembership(token: guestAccessToken!)
        }
        update(active: status.active, expiresAt: status.expiresAt, productID: status.productID)
    }

    func refreshSilently() {
        guard effectiveAccessToken != nil else { return }
        Task { try? await refresh() }
    }

    func bindGuestMembershipAfterLogin() async {
        guard let userToken = userAccessToken, !userToken.isEmpty,
              let guestToken = guestAccessToken, !guestToken.isEmpty else {
            refreshSilently()
            return
        }
        if let status = try? await SleepMembershipService.shared.bindGuestMembership(
            userToken: userToken,
            guestToken: guestToken
        ) {
            update(active: status.active, expiresAt: status.expiresAt, productID: status.productID)
        }
    }

    func logoutUser() {
        try? keychain.setString(nil, for: Self.userTokenAccount)
        if guestAccessToken == nil {
            update(active: false, expiresAt: nil, productID: nil)
        } else {
            refreshSilently()
        }
    }

    private func update(active: Bool, expiresAt: String?, productID: String?) {
        isVIPActive = active
        self.expiresAt = expiresAt
        self.productID = active ? productID : nil
        persist()
    }

    private func persist() {
        defaults.set(isVIPActive, forKey: Key.active)
        if let expiresAt, !expiresAt.isEmpty {
            defaults.set(expiresAt, forKey: Key.expiresAt)
        } else {
            defaults.removeObject(forKey: Key.expiresAt)
        }
        if let productID, !productID.isEmpty {
            defaults.set(productID, forKey: Key.productID)
        } else {
            defaults.removeObject(forKey: Key.productID)
        }
    }

    private static func serverDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}

private struct SleepKeychainStore {
    private let service = Bundle.main.bundleIdentifier ?? "cn.cjym.timesleep"

    func string(for account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setString(_ value: String?, for account: String) throws {
        let query = baseQuery(account: account)
        guard let value, !value.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }
        let data = Data(value.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }
        var item = query
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
