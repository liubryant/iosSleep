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

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// App 内二级页面统一使用的左边缘返回手势。仅占用屏幕最左侧 24pt，
/// 避免影响横向列表、播放器进度条和网页本身的滚动操作。
extension View {
    func appEdgeSwipeBack() -> some View {
        modifier(AppEdgeSwipeBackModifier())
    }
}

private struct AppEdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 24)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .global)
                        .onEnded { value in
                            let horizontalDistance = value.translation.width
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
