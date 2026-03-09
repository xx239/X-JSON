import SwiftUI

struct ClipboardToastView: View {
    let toast: ClipboardToast
    let onView: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(toast.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button("View") {
                onView()
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
    }
}
