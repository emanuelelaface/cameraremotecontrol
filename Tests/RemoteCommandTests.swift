import Foundation
import XCTest
@testable import CRCProtocol

final class RemoteCommandTests: XCTestCase {
    func testAllCameraCommandsMatchOriginalWireProtocol() {
        let modes: [(CameraMode, [UInt8])] = [
            (.immediate, [0x8C, 0x4C, 0x2C, 0x1C]),
            (.delay, [0x84, 0x44, 0x24, 0x14]),
            (.video, [0x88, 0x48, 0x28, 0x18])
        ]
        let buttons: [CameraButton] = [.shutter, .focus, .tele, .wide]
        for (mode, bytes) in modes {
            for (button, byte) in zip(buttons, bytes) {
                var command = RemoteCommand()
                XCTAssertTrue(command.begin(mode: mode, button: button))
                XCTAssertEqual(command.pendingPacket, Data([byte]))
                XCTAssertTrue(command.didSendPacket())
                XCTAssertNil(command.pendingPacket, "No write should occur during the hold.")
                command.release()
                XCTAssertEqual(command.pendingPacket, Data([0x0C]))
                XCTAssertFalse(command.didSendPacket())
                XCTAssertFalse(command.isBusy)
                XCTAssertNil(command.pendingPacket)
            }
        }
    }

    func testPairingNeverIncludesACameraName() {
        XCTAssertEqual(CanonRemote.pairingPacket, Data([0x03]))
    }

    func testRapidTapsCannotOverwriteAPressOrItsRelease() {
        var command = RemoteCommand()
        command.begin(mode: .delay, button: .shutter)
        XCTAssertFalse(command.begin(mode: .video, button: .focus))
        XCTAssertEqual(command.pendingPacket, Data([0x84]))
        XCTAssertTrue(command.didSendPacket())
        XCTAssertFalse(command.begin(mode: .video, button: .shutter))
        command.release()
        XCTAssertFalse(command.begin(mode: .immediate, button: .tele))
        XCTAssertEqual(command.pendingPacket, Data([0x0C]))
        XCTAssertFalse(command.didSendPacket())
        XCTAssertTrue(command.begin(mode: .video, button: .shutter))
        XCTAssertEqual(command.pendingPacket, Data([0x88]))
    }

    func testBluetoothBackpressureRetainsPressUntilSent() {
        var command = RemoteCommand()
        command.begin(mode: .immediate, button: .focus)
        // No didSendPacket call while canSendWriteWithoutResponse is false.
        for _ in 0..<5 {
            XCTAssertEqual(command.pendingPacket, Data([0x4C]))
            XCTAssertTrue(command.isBusy)
        }
        XCTAssertTrue(command.didSendPacket())
        XCTAssertNil(command.pendingPacket)
        XCTAssertTrue(command.isBusy)
    }

    func testBluetoothBackpressureRetainsReleaseUntilSent() {
        var command = RemoteCommand()
        command.begin(mode: .immediate, button: .shutter)
        _ = command.didSendPacket()
        command.release()
        for _ in 0..<5 {
            command.release()
            XCTAssertEqual(command.pendingPacket, Data([0x0C]))
            XCTAssertTrue(command.isBusy)
        }
        XCTAssertFalse(command.didSendPacket())
        XCTAssertFalse(command.isBusy)
    }

    func testLeavingAppBeforePressIsSentCancelsIt() {
        var command = RemoteCommand()
        command.begin(mode: .video, button: .shutter)
        command.release()
        XCTAssertFalse(command.isBusy)
        XCTAssertNil(command.pendingPacket)
        XCTAssertFalse(command.didSendPacket(), "A stale callback must not start a hold.")
    }

    func testLeavingAppDuringHoldQueuesRelease() {
        var command = RemoteCommand()
        command.begin(mode: .video, button: .shutter)
        _ = command.didSendPacket()
        command.release()
        XCTAssertEqual(command.pendingPacket, Data([0x0C]))
        XCTAssertTrue(command.isBusy)
        XCTAssertFalse(command.didSendPacket())
        XCTAssertFalse(command.isBusy)
    }

    func testDisconnectClearsEveryPendingPhase() {
        for phase in 0..<3 {
            var command = RemoteCommand()
            command.begin(mode: .immediate, button: .shutter)
            if phase >= 1 { _ = command.didSendPacket() }
            if phase >= 2 { command.release() }
            command.reset()
            command.release()
            XCTAssertNil(command.pendingPacket)
            XCTAssertFalse(command.isBusy)
            XCTAssertFalse(command.didSendPacket())
            XCTAssertTrue(command.begin(mode: .delay, button: .focus))
            XCTAssertEqual(command.pendingPacket, Data([0x44]))
        }
    }

    func testRepeatedReleaseDoesNotSendGhostCommands() {
        var command = RemoteCommand()
        command.release()
        XCTAssertNil(command.pendingPacket)
        command.begin(mode: .immediate, button: .wide)
        XCTAssertTrue(command.didSendPacket())
        XCTAssertFalse(command.didSendPacket(), "Repeated callbacks must not restart the hold.")
        command.release()
        XCTAssertFalse(command.didSendPacket())
        command.release()
        XCTAssertNil(command.pendingPacket)
        XCTAssertFalse(command.isBusy)
    }
}
