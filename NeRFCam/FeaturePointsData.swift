//
//  FeaturePointsData.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 22/1/23.
//

import Foundation
import ARKit


struct FeaturePointsData: Codable {
    var featurePoints: Array<FeaturePoint> = []
    let file_path: String
}

struct FeaturePoint: Codable {
    /**

     x and y: n normalized coordinates (0.0-1). That means to plot them you need to multiply by the width and height of the frame
     z: Distance in milimiters from the feature point to the camera (positive)
     */

    let x: Float
    let y: Float
    let z: Float
}
