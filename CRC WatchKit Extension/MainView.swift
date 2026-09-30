import SwiftUI

struct MainView: View {
    @StateObject private var bleManager = BLEManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraMode: CameraMode = .immediate

    var body: some View {
        Group {
            if bleManager.state == .ready {
                CRCView(bleManager: bleManager, cameraMode: $cameraMode)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.title2)
                        Text(bleManager.state.message)
                            .multilineTextAlignment(.center)
                        if bleManager.state.isWorking {
                            ProgressView()
                        }
                        if bleManager.state == .scanning {
                            Text("Set the camera's Bluetooth function to Remote, then select Pairing.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        if bleManager.state.canRetry {
                            Button("Retry") { bleManager.retry() }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("CRC")
        .disabled(scenePhase != .active)
        .task(id: scenePhase) {
            switch scenePhase {
            case .active: bleManager.setActive(true)
            case .background: bleManager.setActive(false)
            case .inactive: break // Keep pairing alive while a system permission alert is open.
            @unknown default: bleManager.setActive(false)
            }
        }
    }
}
