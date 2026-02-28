import SwiftUI

struct SettingsView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 22, weight: .black, design: .condensed))
                        .foregroundStyle(Color.hex("#00D4FF"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.hex("#00D4FF"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Divider()
                    .background(Color.hex("#00D4FF").opacity(0.2))
                    .padding(.horizontal, 24)

                // Settings Rows
                VStack(spacing: 16) {
                    SettingsRow(
                        label: "Music",
                        isOn: $gameState.musicEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )

                    SettingsRow(
                        label: "Sound Effects",
                        isOn: $gameState.sfxEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )

                    SettingsRow(
                        label: "Haptics",
                        isOn: $gameState.hapticsEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )
                }
                .padding(.horizontal, 24)

                Divider()
                    .background(Color.hex("#00D4FF").opacity(0.2))
                    .padding(.horizontal, 24)

                Spacer()

                // Version footer
                Text("FREEFALL v1.0")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 24)
            }
        }
    }
}

private struct SettingsRow: View {
    let label: String
    @Binding var isOn: Bool
    let tintColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(tintColor)
        }
    }
}

#Preview {
    SettingsView()
        .environment(GameState())
}
