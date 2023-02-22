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

    
    
    
    init(arFrame: ARFrame, filename: String) {
        // NeRF Studio needs the rows not the columns of the extrinsic matrix
        // Without transposing the extrinsics looks like:
        // simd_float4x4([[0.7122357, -0.2139513, 0.66853964, 0.0],
        //              [0.39161277, 0.9115323, -0.12549302, 0.0],
        //              [-0.582546, 0.35118923, 0.73301184, 0.0],
        //              [0.10054999, 0.17773129, 0.10722073, 1.0]])
        
        // but there is no API to call the rows not the colums, so we transpose it to get:
        // simd_float4x4([[0.7122357, 0.39161277, -0.582546, 0.10054999],
        //              [-0.2139513, 0.9115323, 0.35118923, 0.17773129],
        //              [0.66853964, -0.12549302, 0.73301184, 0.10722073],
        //              [0.0, 0.0, 0.0, 1.0]])
        
        // Acording to the Nerfstudio docs this is what its needed: https://docs.nerf.studio/en/latest/quickstart/data_conventions.html
        // [+X0 +Y0 +Z0 X]
        // [+X1 +Y1 +Z1 Y]
        // [+X2 +Y2 +Z2 Z]
        // [0.0 0.0 0.0 1]
        // You can debug this is correct by moving the camera to down and to the left of the origin and check that X,Y,Z (the origins) are negative
        print("Tranform matrix: \(arFrame.camera.transform)")
        let transformMatrix = arFrame.camera.transform.transpose
        print("Camera transpose: \(transformMatrix)")
        let intrinsics = arFrame.camera.intrinsics
        let imageResolution = arFrame.camera.imageResolution
        file_path = filename
        transform_matrix = [transformMatrix.columns.0, transformMatrix.columns.1, transformMatrix.columns.2, transformMatrix.columns.3]
        fl_x = intrinsics.columns.0.x
        fl_y = intrinsics.columns.1.y
        cx = intrinsics.columns.2.x
        cy = intrinsics.columns.2.y
        w = imageResolution.width
        h = imageResolution.height
        
    }
}
