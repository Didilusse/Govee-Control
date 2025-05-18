//
//  BluetoothManager.swift
//  Govee Control
//
//  Created by Adil Rahmani on 5/17/25.
//

import Foundation
import CoreBluetooth
import AppKit

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Bluetooth Configuration
    private let goveeServiceUUID = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0D1910")
    private let writeCharacteristicUUID = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0D2B11")
    
    // MARK: - Published Properties
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isConnected = false
    @Published var connectedPeripheral: CBPeripheral?
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private let colorMode: BLEColorMode = .modeD
    private let bleBrightnessMax: UInt8 = 0xFF

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - CBCentralManagerDelegate (Fixed Protocol Conformance)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
        case .unauthorized:
            showBluetoothAlert()
        case .resetting:
            print("Bluetooth is resetting")
        case .unsupported:
            print("Bluetooth is not supported")
        case .unknown:
            print("Bluetooth state unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }

    func centralManager(_ central: CBCentralManager,
                      didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any],
                      rssi RSSI: NSNumber) {
        guard !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        
        DispatchQueue.main.async {
            self.discoveredDevices.append(peripheral)
            print("Discovered: \(peripheral.name ?? "Unnamed Device")")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([goveeServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }


    // MARK: - Command Handling
    func sendPowerCommand(isOn: Bool) {
        let command = createCommand([0x33, 0x01, isOn ? 0x01 : 0x00])
        sendCommand(command)
    }

    func sendBrightnessCommand(percentage: Int) {
        let value = UInt8(round(Double(percentage) * Double(bleBrightnessMax) / 100.0))
        let command = createCommand([0x33, 0x04, value])
        sendCommand(command)
    }

    func sendColorCommand(_ color: NSColor) {
        let rgb = color.rgbComponents
        var commandBytes: [UInt8]
        
        switch colorMode {
        case .modeD:
            commandBytes = [0x33, 0x05, 0x0D, rgb.r, rgb.g, rgb.b]
        case .mode1501:
            commandBytes = [0x33, 0x05, 0x15, 0x01, rgb.r, rgb.g, rgb.b, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x74]
        case .mode2:
            commandBytes = [0x33, 0x05, 0x02, rgb.r, rgb.g, rgb.b]
        }
        
        let command = createCommand(commandBytes)
        sendCommand(command)
    }

    private func createCommand(_ bytes: [UInt8]) -> Data {
        var packet = bytes
        var checksum: UInt8 = 0
        
        for byte in packet {
            checksum ^= byte
        }
        
        while packet.count < 19 {
            packet.append(0x00)
        }
        packet.append(checksum)
        
        return Data(packet)
    }

    private func sendCommand(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else { return }
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }


    func connect(to peripheral: CBPeripheral) {
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }


    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        services.forEach { service in
            peripheral.discoverCharacteristics([writeCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        characteristics.forEach { characteristic in
            if characteristic.uuid == writeCharacteristicUUID {
                writeCharacteristic = characteristic
            }
        }
    }
    
    func startScanning() {
            guard centralManager.state == .poweredOn else { return }
            centralManager.scanForPeripherals(
                withServices: nil, // Scan for all devices
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            print("Scanning started")
        }
        
        func stopScanning() {
            centralManager.stopScan()
            print("Scanning stopped")
        }
    
    func showBluetoothAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Bluetooth Access Required"
            alert.informativeText = "Please enable Bluetooth access in System Preferences > Security & Privacy > Privacy > Bluetooth"
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
            }
        }
    }
}

// MARK: - BLEColorMode Enum
enum BLEColorMode {
    case modeD
    case mode1501
    case mode2
}


extension NSColor {
    var rgbComponents: (r: UInt8, g: UInt8, b: UInt8) {
        guard let color = usingColorSpace(.deviceRGB) else { return (0, 0, 0) }
        return (
            UInt8(max(0, min(255, color.redComponent * 255))),
            UInt8(max(0, min(255, color.greenComponent * 255))),
            UInt8(max(0, min(255, color.blueComponent * 255)))
        )
    }
}
