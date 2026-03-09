import SwiftUI

struct StatusBarView: View {
    let status: String
    let isDirty: Bool
    let mode: MainContentMode
    let tabCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(status)
                .font(.system(size: 11))
                .lineLimit(1)

            if isDirty {
                Text("Modified")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            Spacer()

            Text("\(mode.rawValue.capitalized) View")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("Tabs: \(tabCount)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }
}
