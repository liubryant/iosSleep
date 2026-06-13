import SwiftUI

struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum LegalText {
    static let userAgreement = """
    欢迎使用 iosSleep。

    1. 本应用用于个人睡眠习惯记录与声音事件观察，不构成医学诊断。
    2. 用户应确保在合法、合适的环境中使用麦克风监测功能。
    3. 本应用默认在本机处理音频数据，用户可自行删除睡眠记录与缓存。
    4. 因设备电量、系统权限、后台限制等原因，记录结果可能不完整。
    5. 后续如接入云同步或账号系统，将在用户明确授权后进行。
    """

    static let privacyPolicy = """
    iosSleep 重视隐私保护。

    麦克风：用于夜间声音事件识别。第一版默认本地处理，不上传原始音频。

    HealthKit：用于读取和写入睡眠分析数据。应用只请求睡眠相关权限，不读取无关健康数据。

    声音片段：如用户开启保存识别片段，应用仅保存与睡眠事件相关的短音频片段，并提供删除能力。

    缓存清理：清除缓存只删除临时文件，不删除 App 内置声音资源。

    数据控制：用户可以删除本地睡眠记录、缓存和登录状态。
    """
}
