//
//  NeRFData.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 6/11/22.
//

import Foundation
import ARKit

struct NeRFData: Codable {
    let frames: Array<CapturedFrameData>
    let camera_model: String
    // no way of getting distortions in ARkit atm
    let k1: Float
    let k2: Float
    let p1: Float
    let p2: Float
    let fl_x: Float
    let fl_y: Float
    let cx: Float
    let cy: Float
    let w: CGFloat
    let h: CGFloat
    
    init(capturedFrameData: Array<CapturedFrameData>, arFrame: ARFrame) {
        let imageResolution = arFrame.camera.imageResolution
        let intrinsics = arFrame.camera.intrinsics
        frames = capturedFrameData
        fl_x = intrinsics.columns.0.x
        fl_y = intrinsics.columns.1.y
        cx = intrinsics.columns.2.x
        cy = intrinsics.columns.2.y
        w = imageResolution.width
        h = imageResolution.height
        camera_model = "OPENCV"
        k1 = 0.0
        k2 = 0.0
        p1 = 0.0
        p2 = 0.0
        
    }
}
