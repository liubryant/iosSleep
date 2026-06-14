import Foundation
import UIKit

enum AuthError: LocalizedError {
    case server(String)
    case network

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .network: return "网络异常，请稍后重试"
        }
    }
}

struct AppUserLoginResult: Decodable {
    let phone: String
    let newUser: Bool
}

/// 手机号验证码 / 密码登录相关接口。
enum AuthAPI {
    static let baseURL = URL(string: "https://www.cjym123.cn")!

    /// 请求后台发送短信验证码，返回验证码有效期（秒）。
    @discardableResult
    static func requestVerificationCode(phone: String) async throws -> Int {
        let response: APIResponse<SmsCodeData> = try await post(path: "im/bot/login-code", body: ["phone": phone])
        guard response.code == 0 else {
            throw AuthError.server(response.msg)
        }
        return response.data?.expiresIn ?? 300
    }

    /// 手机号 + 短信验证码登录，账号不存在时后台会自动注册。
    static func login(phone: String, code: String) async throws -> AppUserLoginResult {
        let response: APIResponse<AppUserLoginResult> = try await post(
            path: "im/bot/login-by-code",
            body: ["phone": phone, "code": code].merging(deviceInfo, uniquingKeysWith: { a, _ in a })
        )
        guard response.code == 0, let data = response.data else {
            throw AuthError.server(response.msg)
        }
        return data
    }

    /// 手机号 + 密码登录，账号不存在时后台会用该密码自动注册。
    static func login(phone: String, password: String) async throws -> AppUserLoginResult {
        let response: APIResponse<AppUserLoginResult> = try await post(
            path: "im/bot/login-by-password",
            body: ["phone": phone, "password": password].merging(deviceInfo, uniquingKeysWith: { a, _ in a })
        )
        guard response.code == 0, let data = response.data else {
            throw AuthError.server(response.msg)
        }
        return data
    }

    /// 通过短信验证码设置/重置登录密码，账号不存在时会自动注册。
    static func setPassword(phone: String, code: String, password: String) async throws -> AppUserLoginResult {
        let response: APIResponse<AppUserLoginResult> = try await post(
            path: "im/bot/set-password",
            body: ["phone": phone, "code": code, "password": password]
        )
        guard response.code == 0, let data = response.data else {
            throw AuthError.server(response.msg)
        }
        return data
    }

    /// 登录时上报的设备信息：手机型号、iOS 版本、App 名称。
    private static var deviceInfo: [String: String] {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result += String(UnicodeScalar(UInt8(value)))
        }

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""

        return [
            "deviceModel": deviceModel,
            "osVersion": UIDevice.current.systemVersion,
            "appName": appName
        ]
    }

    private struct APIResponse<T: Decodable>: Decodable {
        let code: Int
        let msg: String
        let data: T?
    }

    private struct SmsCodeData: Decodable {
        let expiresIn: Int
    }

    private static func post<T: Decodable>(path: String, body: [String: String]) async throws -> APIResponse<T> {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AuthError.network
        }
        return try JSONDecoder().decode(APIResponse<T>.self, from: data)
    }
}
