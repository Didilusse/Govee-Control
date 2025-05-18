//
//  GoveeViewModel.swift
//  Govee Control
//
//  Created by Adil Rahmani on 5/17/25.
//

import SwiftUI
import AppKit

class GoveeViewModel: ObservableObject {
    private let bluetoothManager = BluetoothManager()
    private let screenManager = ScreenCaptureManager()
    @Published var selectedColor = Color.white
    @Published var screenColorEnabled = false {
        didSet {
            screenColorEnabled ? startScreenSync() : stopScreenSync()
        }
    }
    
    init() {
        screenManager.colorUpdateHandler = { [weak self] color in
            DispatchQueue.main.async {
                self?.selectedColor = Color(color)
                self?.bluetoothManager.sendColorCommand(color)
            }
        }
    }
    
    private func startScreenSync() {
        screenManager.startMirroring()
    }
    
    private func stopScreenSync() {
        screenManager.stopMirroring()
    }
}
