//
//  FrameTranslator.swift
//  FacesVision
//
//  Created by Tymofii Dolenko on 7/17/19.
//  Copyright © 2019 Tymofii Dolenko. All rights reserved.
//

import UIKit
import AVKit

struct FrameTranslator {
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
