//
//  ContentView.swift
//  Govee Control
//
//  Created by Adil Rahmani on 5/17/25.
//
import SwiftUI
import CoreBluetooth  // Add this import

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var selectedColor = Color.white
    @State private var brightness: Double = 50
    @State private var isPoweredOn = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection Status
            HStack {
                Text("Status:")
                Text(bluetoothManager.isConnected ? "Connected" : "Disconnected")
                    .foregroundColor(bluetoothManager.isConnected ? .green : .red)
            }
            
            // Device List
            List(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                HStack {
                    Text(device.name ?? "Unknown Device")
                    Spacer()
                    if bluetoothManager.connectedPeripheral?.identifier == device.identifier {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !bluetoothManager.isConnected {
                        bluetoothManager.connect(to: device)  // Fixed connection call
                    }
                }
            }
            .frame(height: 200)
            
            // Controls Group
            Group {
                // Power Control
                HStack {
                    Text("Power:")
                    Toggle("", isOn: $isPoweredOn)
                        .toggleStyle(.switch)
                        .onChange(of: isPoweredOn) { newValue in
                            bluetoothManager.sendPowerCommand(isOn: newValue)
                        }
                }
                
                // Brightness Control
                HStack {
                    Text("Brightness:")
                    Slider(value: $brightness, in: 0...100, step: 1)
                        .onChange(of: brightness) { newValue in
                            bluetoothManager.sendBrightnessCommand(percentage: Int(newValue))
                        }
                    Text("\(Int(brightness))%")
                }
                
                // Color Picker
                ColorPicker("Select Color", selection: $selectedColor)
                    .onChange(of: selectedColor) { newColor in
                        bluetoothManager.sendColorCommand(NSColor(newColor))
                    }
            }
            .disabled(!bluetoothManager.isConnected)
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            bluetoothManager.startScanning()
        }
        .onDisappear {
            bluetoothManager.stopScanning()
        }
    }
       
}

extension Color {
    func toNSColor() -> NSColor? {
        NSColor(self)
    }
}

#Preview {
    ContentView()
}
