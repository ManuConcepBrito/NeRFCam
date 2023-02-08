//
//  FrameInformation.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 8/2/23.
//

import Foundation
import ARKit

struct FrameInformation {
    let view_matrix: simd_float4x4
    let projectPoint: (SCNVector3) -> SCNVector3
    let file_path: String
    
    init(arView: ARSCNView, arCamera: ARCamera, filePath: String) {
        file_path = filePath
        projectPoint = arView.projectPoint
        let interfaceOrientation = arView.window?.windowScene?.interfaceOrientation ?? .landscapeLeft
        // transformation from the feature point to distances from the point to the camera in meters (since the origin is in the camera)
        view_matrix = arCamera.viewMatrix(for: interfaceOrientation)
        print("View Matrix at init: \(view_matrix)")
        print("Project Point: \(projectPoint)")
    }
    func projectRawFeaturePointsToCamera(rawFeaturePoints: [vector_float3]) -> Array<SLAMPoint> {
        var slam_points: Array<SLAMPoint> = []
        for point in rawFeaturePoints {
            let point_to_camera = getPointToCameraDistances(point: point)
            // stay only with z, the distance from the point to the camera (negative) in meters
            // convert to a positive value and to milimiters
            let z = point_to_camera.z * -1 * 1000
            // get the normalized x and y coordinates (0-1) in the viewport: for iPhone 13 is, for example: 390x 844 (but they are normalized to 0-1)
            let x_y_viewport_coords = getViewportCoordinates(point: point)
            
            // we need to filter negative values for x and y as it indicates that a point is projected outside of the view
            if (x_y_viewport_coords.x.sign == .plus && x_y_viewport_coords.y.sign == .plus) && (x_y_viewport_coords.x.isLess(than: 1.0) && x_y_viewport_coords.y.isLess(than: 1.0)) {
                let slam_point = SLAMPoint(x: x_y_viewport_coords.x, y: x_y_viewport_coords.y, z: z)
                slam_points.append(slam_point)
            }
        }
        return slam_points
        
    }
    func getViewportCoordinates(point: SIMD3<Float>) -> SCNVector3 {
        let scn_point = SCNVector3(point)
        let viewport_coords = projectPoint(scn_point)
        // normalize the viewport coordinates between 0 and 1 for easier plotting in Python
        let viewport_coords_normalized = normalizeCoordinates(point: viewport_coords)
        
        return viewport_coords_normalized
    }
    
    func normalizeCoordinates(point: SCNVector3) -> SCNVector3 {
        let x_pixel = CGFloat(point.x) / UIScreen.main.bounds.width
        let y_pixel = CGFloat(point.y) / UIScreen.main.bounds.height
        return SCNVector3(x: Float(x_pixel), y: Float(y_pixel), z: 0.0)
    }
    
    
    func getPointToCameraDistances(point: SIMD3<Float>) -> SIMD4<Float> {
        // conversion to camera origin, units are in meters, negative means that point is below and to the left of the camera
        let point_from_camera = view_matrix * SIMD4<Float>(point, 1)
        
        return point_from_camera
    }
    
}


struct SLAMPoint: Codable {
    /**
     x and y: n normalized coordinates (0.0-1). That means to plot them you need to multiply by the width and height of the frame
     z: Distance in milimiters from the feature point to the camera (positive)
     */

    let x: Float
    let y: Float
    let z: Float
}

struct FramePoints: Codable {
    var slam_points: Array<SLAMPoint>
    let file_path: String
}
