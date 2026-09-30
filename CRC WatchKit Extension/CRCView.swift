import SwiftUI

struct CRCView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var cameraMode: CameraMode

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Picker("Camera Mode", selection: $cameraMode) {
                    ForEach(CameraMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .frame(height: 64)
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Button("T") { send(.tele) }
                        .accessibilityLabel("Zoom in")
                    Button("AF") { send(.focus) }
                        .accessibilityLabel("Autofocus")
                    Button("W") { send(.wide) }
                        .accessibilityLabel("Zoom out")
                }

                Button(action: { send(.shutter) }) {
                    Label(cameraMode == .video ? "Record / Stop" : "Shutter", systemImage: "camera.shutter.button")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
            .disabled(!bleManager.canSendCommand)
        }
    }

    private func send(_ button: CameraButton) {
        bleManager.clickButton(mode: cameraMode, button: button)
    }
}
