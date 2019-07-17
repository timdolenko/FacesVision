//
//  CGRect+Extension.swift
//  FacesVision
//
//  Created by Tymofii Dolenko on 7/17/19.
//  Copyright © 2019 Tymofii Dolenko. All rights reserved.
//

import UIKit

extension CGRect {
    
    var center: CGPoint {
        return CGPoint.init(x: midX, y: midY)
    }
    
}

extension CGPoint {
    
    func distance(to point: CGPoint) -> Float {
        return hypotf(Float(self.x - point.x), Float(self.y - point.y))
    }
    
}
