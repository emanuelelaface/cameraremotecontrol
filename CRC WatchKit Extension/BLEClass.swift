import Combine
import CoreBluetooth
import Foundation

@MainActor
final class BLEManager: NSObject, ObservableObject {
    enum ConnectionState: Equatable {
        case idle, bluetoothOff, unauthorized, unsupported, scanning, connecting, ready
        case failed(String)

        var message: String {
            switch self {
            case .idle: return "Preparing Bluetooth…"
            case .bluetoothOff: return "Turn on Bluetooth on your Apple Watch."
            case .unauthorized: return "Allow CRC to use Bluetooth in Settings > Privacy & Security > Bluetooth."
            case .unsupported: return "Bluetooth is unavailable on this device."
            case .scanning: return "Looking for your camera…"
            case .connecting: return "Connecting to camera…"
            case .ready: return "Connected"
            case .failed(let message): return message
            }
        }

        var isWorking: Bool {
            self == .idle || self == .scanning || self == .connecting
        }

        var canRetry: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var isSendingCommand = false

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var pairingCharacteristic: CBCharacteristic?
    private var eventCharacteristic: CBCharacteristic?
    private var pairingSent = false
    private var isActive = false
    private var command = RemoteCommand()
    private var timeoutTask: Task<Void, Never>?
    private var releaseTask: Task<Void, Never>?

    private let serviceUUID = CBUUID(string: CanonRemote.serviceUUID)
    private let pairingUUID = CBUUID(string: CanonRemote.pairingUUID)
    private let eventUUID = CBUUID(string: CanonRemote.eventUUID)

    var canSendCommand: Bool { isActive && state == .ready && !isSendingCommand }

    func setActive(_ active: Bool) {
        isActive = active
        if active {
            if central == nil {
                // Core Bluetooth delivers every delegate callback on the main queue.
                central = CBCentralManager(delegate: self, queue: .main)
            } else if let central, peripheral == nil {
                centralManagerDidUpdateState(central)
            } else if state == .ready {
                flushCommand()
            }
        } else {
            if central?.isScanning == true { central?.stopScan() }
            // Keep an established connection so Core Bluetooth can drain the
            // release packet. Canceling immediately can discard queued writes.
            // Pending, unsent presses are discarded when leaving the foreground.
            releaseTask?.cancel()
            command.release()
            if state == .ready {
                isSendingCommand = command.isBusy
                if command.isBusy {
                    flushCommand()
                } else {
                    timeoutTask?.cancel()
                    timeoutTask = nil
                }
            } else {
                resetConnection()
                state = .idle
            }
        }
    }

    func retry() {
        guard isActive, central?.state == .poweredOn else { return }
        resetConnection()
        startScanning()
    }

    func clickButton(mode: CameraMode, button: CameraButton) {
        guard canSendCommand, command.begin(mode: mode, button: button) else { return }
        isSendingCommand = true
        scheduleTimeout(seconds: 3, message: "Could not send the command. Try reconnecting.")
        flushCommand()
    }

    private func startScanning() {
        guard isActive, let central, central.state == .poweredOn,
              peripheral == nil, !central.isScanning else { return }
        state = .scanning
        // Filtering also handles advertisements whose Canon UUID is not first.
        central.scanForPeripherals(withServices: [serviceUUID])
        scheduleTimeout(seconds: 20, message: "No camera found. Enable Bluetooth Remote / Pairing on the camera, then retry.")
    }

    private func scheduleTimeout(seconds: UInt64, message: String) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.fail(message)
        }
    }

    private func fail(_ message: String) {
        resetConnection()
        state = .failed(message)
    }

    private func resetConnection() {
        timeoutTask?.cancel()
        timeoutTask = nil
        releaseTask?.cancel()
        releaseTask = nil
        if central?.isScanning == true { central?.stopScan() }
        let oldPeripheral = peripheral
        peripheral = nil // Ignore callbacks from the connection being torn down.
        oldPeripheral?.delegate = nil
        if let oldPeripheral, oldPeripheral.state != .disconnected,
           central?.state == .poweredOn {
            central?.cancelPeripheralConnection(oldPeripheral)
        }
        pairingCharacteristic = nil
        eventCharacteristic = nil
        pairingSent = false
        command.reset()
        isSendingCommand = false
    }

    private func sendPairingIfReady() {
        guard isActive, state == .connecting, !pairingSent,
              let peripheral, peripheral.state == .connected,
              let pairingCharacteristic, eventCharacteristic != nil,
              peripheral.canSendWriteWithoutResponse else { return }
        peripheral.writeValue(CanonRemote.pairingPacket, for: pairingCharacteristic, type: .withoutResponse)
        pairingSent = true
        // The Canon protocol has no pairing acknowledgement. Ready means both
        // writable characteristics exist and the pairing packet has been queued.
        timeoutTask?.cancel()
        timeoutTask = nil
        state = .ready
    }

    private func flushCommand() {
        guard state == .ready, let peripheral, peripheral.state == .connected,
              let eventCharacteristic, let packet = command.pendingPacket,
              peripheral.canSendWriteWithoutResponse else { return }
        peripheral.writeValue(packet, for: eventCharacteristic, type: .withoutResponse)
        if command.didSendPacket() {
            releaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 60_000_000)
                guard !Task.isCancelled, let self else { return }
                self.command.release()
                self.flushCommand()
            }
        } else {
            isSendingCommand = false
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }
}

// The central is created on .main; these ObjC delegate protocols don't express
// that isolation. @preconcurrency keeps the Swift 6 main-actor runtime checks.
extension BLEManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isActive { startScanning() }
        case .poweredOff:
            resetConnection()
            state = .bluetoothOff
        case .unauthorized:
            resetConnection()
            state = .unauthorized
        case .unsupported:
            resetConnection()
            state = .unsupported
        case .unknown, .resetting:
            resetConnection()
            state = .idle
        @unknown default:
            resetConnection()
            state = .unsupported
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard isActive, state == .scanning, self.peripheral == nil else { return }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        state = .connecting
        scheduleTimeout(seconds: 20, message: "Connection timed out. Check the camera's Bluetooth pairing, then retry.")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral === self.peripheral, isActive, state == .connecting else { return }
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        fail("Could not connect to the camera. \(error?.localizedDescription ?? "Please retry.")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        resetConnection()
        state = .idle
        if isActive { startScanning() }
    }
}

extension BLEManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === self.peripheral, state == .connecting else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            fail("Camera remote service is unavailable. Enable Bluetooth Remote on the camera.")
            return
        }
        peripheral.discoverCharacteristics([pairingUUID, eventUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral === self.peripheral, state == .connecting, service.uuid == serviceUUID else { return }
        guard error == nil,
              let pairing = service.characteristics?.first(where: { $0.uuid == pairingUUID }),
              let event = service.characteristics?.first(where: { $0.uuid == eventUUID }),
              pairing.properties.contains(.writeWithoutResponse),
              event.properties.contains(.writeWithoutResponse) else {
            fail("This camera does not provide the expected Bluetooth remote controls.")
            return
        }
        pairingCharacteristic = pairing
        eventCharacteristic = event
        sendPairingIfReady()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard peripheral === self.peripheral else { return }
        sendPairingIfReady()
        flushCommand()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard peripheral === self.peripheral,
              invalidatedServices.contains(where: { $0.uuid == serviceUUID }) else { return }
        fail("Camera services changed. Reconnect to continue.")
    }
}
