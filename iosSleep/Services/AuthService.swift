import Foundation

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

struct AuthResult {
    let token: String
    let userId: String
}

/// 手机号 + 验证码登录相关接口。baseURL 为占位地址，接入真实后台时替换为正式域名即可。
enum AuthAPI {
    static let baseURL = URL(string: "https://www.cjym123.cn/api")!

    /// 请求后台发送短信验证码。
    static func requestVerificationCode(phone: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["phone": phone])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
    }

    /// 使用手机号 + 验证码登录，返回登录凭证。
    static func login(phone: String, code: String) async throws -> AuthResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["phone": phone, "code": code])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)

        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        guard let token = result.token else {
            throw AuthError.server(result.message ?? "登录失败，请重试")
        }
        return AuthResult(token: token, userId: result.userId ?? phone)
    }

    private struct APIResponse: Decodable {
        let message: String?
    }

    private struct LoginResponse: Decodable {
        let message: String?
        let token: String?
        let userId: String?
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.network }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiResponse = try? JSONDecoder().decode(APIResponse.self, from: data)
            throw AuthError.server(apiResponse?.message ?? "请求失败，请稍后重试")
        }
    }
}
