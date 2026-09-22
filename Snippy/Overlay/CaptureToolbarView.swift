import SwiftUI

struct CaptureToolbarView: View {
    @ObservedObject var state: OverlayState
    var onChooseScreen: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    if mode == .screen {
                        onChooseScreen()
                    } else {
                        state.mode = mode
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: mode.symbolName)
                            .font(.system(size: 15, weight: .medium))
                        Text(mode.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(state.mode == mode ? Color.primary : Color.secondary)
                    .frame(width: 78, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(state.mode == mode ? Color.primary.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 4)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 46)
            }
            .buttonStyle(.plain)
            .help(L10n.toolbarCancel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.22), radius: 12, y: 2)
    }
}
