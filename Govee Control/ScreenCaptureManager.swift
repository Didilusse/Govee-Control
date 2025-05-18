//
//  ScreenCaptureManager.swift
//  Govee Control
//
//  Created by Adil Rahmani on 5/17/25.
//
import Foundation
import ScreenCaptureKit
import AppKit
import CoreMedia

class ScreenCaptureManager: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var timer: Timer?
    var colorUpdateHandler: ((NSColor) -> Void)?
    
    // Updated initialization with correct parameters
    func startMirroring(interval: TimeInterval = 0.5) {
        stopMirroring()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureScreen()
        }
    }
    
    func stopMirroring() {
        timer?.invalidate()
        stream?.stopCapture()
    }
    
    func captureScreen() {
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }
                
                // Fixed parameter order
                let filter = SCContentFilter(display: display,
                                          excludingApplications: [],
                                          exceptingWindows: [])
                
                let config = SCStreamConfiguration()
                config.width = 100
                config.height = 100
                
                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
                try await stream!.startCapture()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.stream?.stopCapture()
                }
            } catch {
                print("Capture error: \(error)")
            }
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let image = imageFromSampleBuffer(sampleBuffer) else { return }
        guard let color = dominantColor(from: image) else { return }
        DispatchQueue.main.async {
            self.colorUpdateHandler?(color)
        }
    }
    
    // Fixed image creation from sample buffer
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> NSImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    func dominantColor(from image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        let extent = ciImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y,
                                  z: extent.size.width, w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: inputExtent]),
              let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        return NSColor(red: CGFloat(bitmap[0])/255,
                     green: CGFloat(bitmap[1])/255,
                     blue: CGFloat(bitmap[2])/255,
                     alpha: 1)
    }
}
