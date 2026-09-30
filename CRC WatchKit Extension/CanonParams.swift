import Foundation

enum CameraMode: UInt8, CaseIterable, Identifiable {
    case immediate = 0x0C
    case delay = 0x04
    case video = 0x08

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .immediate: return "Immediate"
        case .delay: return "2s Delay"
        case .video: return "Video"
        }
    }
}

enum CameraButton: UInt8, CaseIterable {
    case shutter = 0x80
    case focus = 0x40
    case tele = 0x20
    case wide = 0x10
}

enum CanonRemote {
    static let serviceUUID = "00050000-0000-1000-0000-D8492FFFA821"
    static let pairingUUID = "00050002-0000-1000-0000-D8492FFFA821"
    static let eventUUID = "00050003-0000-1000-0000-D8492FFFA821"

    // Keep the name empty: sending a name can hang the EOS R's Bluetooth
    // after a camera restart (see the original project's protocol notes).
    static let pairingPacket = Data([0x03])
    // Preserve the original, camera-tested neutral packet in every mode.
    static let releasePacket = Data([0x0C])
}

/// Tracks one button pulse, including Bluetooth backpressure. The hold starts
/// only when the press is sent, and a release always precedes a new press.
struct RemoteCommand {
    private enum Phase {
        case idle
        case pressPending(Data)
        case holding
        case releasePending
    }

    private var phase: Phase = .idle

    var isBusy: Bool {
        if case .idle = phase { return false }
        return true
    }

    var pendingPacket: Data? {
        switch phase {
        case .pressPending(let packet): return packet
        case .releasePending: return CanonRemote.releasePacket
        case .idle, .holding: return nil
        }
    }

    @discardableResult
    mutating func begin(mode: CameraMode, button: CameraButton) -> Bool {
        guard !isBusy else { return false }
        phase = .pressPending(Data([mode.rawValue | button.rawValue]))
        return true
    }

    /// Returns true when the caller must start the 60 ms hold timer.
    mutating func didSendPacket() -> Bool {
        switch phase {
        case .pressPending:
            phase = .holding
            return true
        case .releasePending:
            phase = .idle
        case .idle, .holding:
            break
        }
        return false
    }

    mutating func release() {
        switch phase {
        case .holding: phase = .releasePending
        case .pressPending: phase = .idle // Discard unsent presses when leaving the app.
        case .idle, .releasePending: break
        }
    }

    mutating func reset() {
        phase = .idle
    }
}
