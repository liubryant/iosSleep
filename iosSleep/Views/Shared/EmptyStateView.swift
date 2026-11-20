import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(verbatim: SleepL10n.text(title))
                .font(.headline)

            Text(verbatim: SleepL10n.text(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// App 内二级页面统一使用的起始边缘返回手势，仅占用边缘 24pt。
/// 避免影响横向列表、播放器进度条和网页本身的滚动操作。
extension View {
    func appEdgeSwipeBack() -> some View {
        modifier(AppEdgeSwipeBackModifier())
    }
}

private struct AppEdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 24)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .global)
                        .onEnded { value in
                            let horizontalDistance = value.translation.width * (layoutDirection == .rightToLeft ? -1 : 1)
                            let verticalDistance = abs(value.translation.height)
                            guard horizontalDistance > 72,
                                  horizontalDistance > verticalDistance * 1.2 else { return }
                            dismiss()
                        }
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .zIndex(999)
        }
    }
}
