//
//  CapturedFrameData.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 3/11/22.
//

import Foundation
import ARKit

struct CapturedFrameData: Codable {
    // Data convention according to NeRFStudio: https://docs.nerf.studio/en/latest/quickstart/data_conventions.html
    let file_path: String
    let transform_matrix: Array<SIMD4<Float>>
    let fl_x: Float
    let fl_y: Float
    let cx: Float
    let cy: Float
    let w: CGFloat
    let h: CGFloat

    
    
    
    init(arFrame: ARFrame, width: CGFloat, height: CGFloat, filename: String) {
        // NeRF Studio needs the rows not the columns of the extrinsic matrix
        let transformMatrix = arFrame.camera.transform.transpose
        let intrinsics = arFrame.camera.intrinsics
        let imageResolution = arFrame.camera.imageResolution
        file_path = filename
        transform_matrix = [transformMatrix.columns.0, transformMatrix.columns.1, transformMatrix.columns.2, transformMatrix.columns.3]
        fl_x = intrinsics.columns.0.x
        fl_y = intrinsics.columns.1.y
        cx = intrinsics.columns.2.x
        cy = intrinsics.columns.2.y
        w = width
        h = height
        //w = imageResolution.width
        //h = imageResolution.height
        
    }
}
