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

class ViewController: UIViewController {
    
    @IBOutlet weak var resultsView: UIView!
    @IBOutlet weak var resultsImageView: UIImageView!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var processor: CaptureProcessor!
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var boxes: [UIImageView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        processor = CaptureProcessor.init(delegate: self)
        
        configureGesture()
        configurePreview()
        updateOrientation()
    }
    
    func configureGesture() {
        let gesture = UITapGestureRecognizer.init(target: self, action: #selector(didTapScreen))
        view.addGestureRecognizer(gesture)
    }
    
    func configurePreview() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: processor.captureSession)
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.bounds
        self.previewLayer = previewLayer
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
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer?.frame = view.bounds
        processor.frameTranslator.frame = view.bounds
        processor.frameTranslator.orientation = orientation
    }
    
    func resetMode() {
        processor.captureSession.startRunning()
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
    }
    
    @objc func didTapScreen() {
        if processor.mode == .captured {
            processor.mode = .none
            resetMode()
        } else {
            processor.mode = .requestedCapture
        }
    }
}

extension ViewController: CaptureProcessorDelegate {
    
    func didCaptureImage(_ image: UIImage) {
        resultsImageView.image = image
        resultsView.isHidden = false
        resultsView.alpha = 1
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
