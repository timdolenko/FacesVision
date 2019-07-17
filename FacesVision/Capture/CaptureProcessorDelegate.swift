//
//  CaptureProcessorDelegate.swift
//  FacesVision
//
//  Created by Tymofii Dolenko on 7/17/19.
//  Copyright © 2019 Tymofii Dolenko. All rights reserved.
//

import UIKit

protocol CaptureProcessorDelegate: class {
    
    var boxes: [UIImageView] { get set }
    
    func positionFace(at rect: CGRect, view: UIView)
    func highlightFace(at rect: CGRect, view: UIView, identifier: String, confidence: Float)
    func getImageView(at rect: CGRect) -> UIImageView
    func didCaptureImage(_ image: UIImage)
}
