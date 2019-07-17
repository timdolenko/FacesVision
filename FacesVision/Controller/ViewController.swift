//
//  ViewController.swift
//  FacesVision
//
//  Created by Tymofii Dolenko on 7/14/19.
//  Copyright © 2019 Tymofii Dolenko. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVKit

class GenderColor {
    static var male: UIColor {
        return UIColor.init(red: 52.0 / 255.0, green: 152.0 / 255.0, blue: 219.0 / 255.0, alpha: 1.0)
    }
    static var female: UIColor {
        return UIColor.init(red: 255.0 / 255.0, green: 64.0 / 255.0, blue: 129.0 / 255.0, alpha: 1.0)
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var resultsView: UIView!
    @IBOutlet weak var resultsImageView: UIImageView!
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var captureSession: AVCaptureSession!
    
    var convert: ConvertObject = ConvertObject.init(frame: .zero, captureSize: .zero, orientation: .landscapeLeft)
    var previewLayer: AVCaptureVideoPreviewLayer?
    var timer: Timer?
    var boxes: [UIImageView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let gesture = UITapGestureRecognizer.init(target: self, action: #selector(didTapScreen))
        view.addGestureRecognizer(gesture)
        
        let captureSession = AVCaptureSession()
        
        //let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.bounds
        self.previewLayer = previewLayer
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.init(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        self.captureSession = captureSession
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer?.frame = view.bounds
        convert.frame = view.bounds
        convert.orientation = orientation
    }
    
    struct ConvertObject {
        var frame: CGRect
        var captureSize: CGRect
        var orientation: AVCaptureVideoOrientation
        
        func convertBoundingRect(_ boundingRect: CGRect) -> CGRect {
            
            var x = frame.width * boundingRect.origin.x
            let height = frame.height * boundingRect.height
            var y = frame.height * (1 - boundingRect.origin.y) - height
            let width = frame.width * boundingRect.width
            
            if orientation == .landscapeLeft {
                x = frame.width * (1 - boundingRect.origin.x) - width
                y = frame.height * boundingRect.origin.y
            }
            
            return CGRect.init(x: x, y: y, width: width, height: height)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateOrientation()
    }
    
    func updateOrientation() {
        guard let connection = previewLayer?.connection else { return }
        
        let currentDevice: UIDevice = UIDevice.current
        
        let orientation: UIDeviceOrientation = currentDevice.orientation
        
        let previewLayerConnection : AVCaptureConnection = connection
        
        if previewLayerConnection.isVideoOrientationSupported {
            
            switch (orientation) {
                
            case .landscapeLeft:
                updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                break
                
            default:
                updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                break
            }
        }
    }
    
    var isImageCaptured = false
    var shouldProcess = false
    
    @objc func didTapScreen() {
        if !shouldProcess && isImageCaptured {
            isImageCaptured = false
            captureSession.startRunning()
            UIView.animate(withDuration: 0.5, animations: { [weak self] in
                guard let `self` = self else { return }
                self.resultsView.alpha = 0
            }) { [weak self] (isCompleted) in
                guard let `self` = self else { return }
                self.resultsView.isHidden = true
                self.boxes.forEach({ (box) in
                    box.alpha = 0
                })
            }
        } else if !shouldProcess {
            shouldProcess = true
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !shouldProcess {
            return
        }
        
        shouldProcess = false
        isImageCaptured = true
        
        captureSession.stopRunning()
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        processCapture(pixelBuffer: pixelBuffer)
    }
    
    func processCapture(pixelBuffer: CVPixelBuffer) {
        let ciimage = CIImage.init(cvPixelBuffer: pixelBuffer)
        convert.captureSize = ciimage.extent
        
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
            self.resultsImageView.image = UIImage.init(cgImage: cgImage)
            self.resultsView.isHidden = false
            self.resultsView.alpha = 1
        }
    }
    
    func processFaceObservations(_ observations: [VNFaceObservation], ciimage: CIImage) {
        
        let availableViews: [UIImageView] = self.boxes
        
        var map: [UIImageView:VNFaceObservation] = [:]
        
        var faceObservations: [VNFaceObservation] = observations
        
        for view in availableViews {
            
            faceObservations = faceObservations.sorted(by: {
                let c1 = convert.convertBoundingRect($0.boundingBox).center
                let c2 = convert.convertBoundingRect($1.boundingBox).center
                
                let c = view.frame.center
                
                return c.distance(to: c1) < c.distance(to: c2)
            })
            
            guard !faceObservations.isEmpty else { break }
            
            guard let nearestFace = faceObservations.first else { continue }
            
            faceObservations.remove(at: 0)
            
            map[view] = nearestFace
        }
        
        for observation in faceObservations {
            let view = getImageView(at: convert.convertBoundingRect(observation.boundingBox))
            map[view] = observation
        }
        
        let unusedViews = availableViews.filter { !map.keys.contains($0) }
        
        unusedViews.forEach { (view) in
            view.removeFromSuperview()
        }
        
        self.boxes = Array(map.keys)
        
        for (view,observation) in map {
            let rect: CGRect = convert.convertBoundingRect(observation.boundingBox)
            
            positionFace(at: rect, view: view)
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
                self.highlightFace(at: faceRect, view: faceView, identifier: topResult.identifier, confidence: topResult.confidence)
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
    
    func positionFace(at rect: CGRect, view: UIView) {
        UIView.animate(withDuration: 0.1) {
            view.alpha = 1
            view.frame = rect
        }
    }
    
    func highlightFace(at rect: CGRect, view: UIView, identifier: String, confidence: Float) {
        let color: UIColor = getColor(for: identifier, confidence: confidence)
        
        UIView.animate(withDuration: 0.1) {
            view.tintColor = color
        }
    }
    
    func getColor(for identifier: String, confidence: Float) -> UIColor {
        if confidence < 0.7 {
            return .white
        } else if identifier == "Male" {
            return GenderColor.male
        }
        return GenderColor.female
    }
    
    func getImageView(at rect: CGRect) -> UIImageView {
        let imageView = UIImageView.init(frame: rect)
        imageView.contentMode = .scaleAspectFit
        imageView.image = #imageLiteral(resourceName: "face_bounds.pdf")
        imageView.tintColor = .white
        imageView.alpha = 0
        resultsView.addSubview(imageView)
        return imageView
    }
}
