//
//  CaptureProcessor.swift
//  FacesVision
//
//  Created by Tymofii Dolenko on 7/17/19.
//  Copyright © 2019 Tymofii Dolenko. All rights reserved.
//

import Foundation
import CoreML
import Vision
import AVKit

class CaptureProcessor: NSObject {
    
    weak var delegate: CaptureProcessorDelegate!
    
    var captureSession: AVCaptureSession!
    
    var frameTranslator: FrameTranslator!
    
    enum CaptureMode {
        case none
        case requestedCapture
        case captured
    }
    
    var mode: CaptureMode = .none
    
    init(delegate: CaptureProcessorDelegate) {
        super.init()
        
        self.delegate = delegate
        frameTranslator = FrameTranslator.init(frame: .zero, captureSize: .zero, orientation: .landscapeLeft)
        self.configureCaptureSession()
    }
    
    func configureCaptureSession() {
        let captureSession = AVCaptureSession()
        
        // For front camera
        //let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.init(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        self.captureSession = captureSession
    }
}

extension CaptureProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if mode != .requestedCapture {
            return
        }
        
        mode = .captured
        
        captureSession.stopRunning()
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        processCapture(pixelBuffer: pixelBuffer)
    }
}

extension CaptureProcessor {
    
    func processCapture(pixelBuffer: CVPixelBuffer) {
        let ciimage = CIImage.init(cvPixelBuffer: pixelBuffer)
        frameTranslator.captureSize = ciimage.extent
        
        let detectionRequest = VNDetectFaceRectanglesRequest.init { [weak self] (request, error) in
            
            guard let results = request.results?.compactMap({ $0 as? VNFaceObservation }) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.processFaceObservations(results, ciimage: ciimage)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        try? handler.perform([detectionRequest])
        
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciimage, from: ciimage.extent) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.delegate.didCaptureImage(UIImage.init(cgImage: cgImage))
        }
    }
    
    func processFaceObservations(_ observations: [VNFaceObservation], ciimage: CIImage) {
        
        let availableViews: [UIImageView] = delegate.boxes
        
        var map: [UIImageView:VNFaceObservation] = [:]
        
        var faceObservations: [VNFaceObservation] = observations
        
        for view in availableViews {
            
            faceObservations = faceObservations.sorted(by: {
                let c1 = frameTranslator.convertBoundingRect($0.boundingBox).center
                let c2 = frameTranslator.convertBoundingRect($1.boundingBox).center
                
                let c = view.frame.center
                
                return c.distance(to: c1) < c.distance(to: c2)
            })
            
            guard !faceObservations.isEmpty else { break }
            
            guard let nearestFace = faceObservations.first else { continue }
            
            faceObservations.remove(at: 0)
            
            map[view] = nearestFace
        }
        
        for observation in faceObservations {
            let view = delegate.getImageView(at: frameTranslator.convertBoundingRect(observation.boundingBox))
            map[view] = observation
        }
        
        let unusedViews = availableViews.filter { !map.keys.contains($0) }
        
        unusedViews.forEach { (view) in
            view.removeFromSuperview()
        }
        
        delegate.boxes = Array(map.keys)
        
        for (view,observation) in map {
            let rect: CGRect = frameTranslator.convertBoundingRect(observation.boundingBox)
            
            delegate.positionFace(at: rect, view: view)
            detectGender(faceObservation: observation, ciimage: ciimage, faceView: view, faceRect: rect)
        }
    }
    
    func detectGender(faceObservation: VNFaceObservation, ciimage: CIImage, faceView: UIView, faceRect: CGRect) {
        
        guard let model = try? VNCoreMLModel.init(for: GenderNet().model) else { return }
        
        let genderRequest = VNCoreMLRequest.init(model: model) { [weak self] request, error in
            
            guard let results = request.results as? [VNClassificationObservation] else { return }
            guard let topResult = results.first else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.delegate.highlightFace(at: faceRect, view: faceView, identifier: topResult.identifier, confidence: topResult.confidence)
            }
        }
        
        let boundingRect = faceObservation.boundingBox
        let x = ciimage.extent.width * (boundingRect.origin.x - 0.05)
        let height = ciimage.extent.height * (boundingRect.height + 0.1)
        let y = ciimage.extent.height * (boundingRect.origin.y - 0.05)
        let width = ciimage.extent.width * (boundingRect.width + 0.1)
        
        let rect = CGRect.init(x: x, y: y, width: width, height: height)
        
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciimage, from: rect) else { return }
        
        let handler = VNImageRequestHandler.init(cgImage: cgImage)
        
        try? handler.perform([genderRequest])
    }
}
