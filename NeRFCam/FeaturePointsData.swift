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
    
    init(arView: ARSCNView, arCamera: ARCamera, rawFeaturePoints: [vector_float3], filename: String) {
        file_path = filename
        for point in rawFeaturePoints {
            let point_to_camera_distances = getPointToCameraDistances(arCamera: arCamera, point: point)
            // stay only with z, the distance from the point to the camera (negative) in meters
            // convert to a positive value and to milimiters
            let z = point_to_camera_distances.z * -1 * 1000
            // get the viewport coordinates for x and y, viewport for iPhone 13 is, for example: 390x 844
            let viewport_coords = getViewportCoordinates(arView: arView, point: point)
            // normalize the viewport coordinates for easier plotting in Python
            let viewport_coords_normalized = normalizeCoordinates(point: viewport_coords)
            // we need to filter negative values for x and y as it indicates that a point is projected outside of the view
            if (viewport_coords_normalized.x.sign == .plus && viewport_coords_normalized.y.sign == .plus) {
                let feature_point = FeaturePoint(x: viewport_coords_normalized.x, y: viewport_coords_normalized.y, z: z)
                //print("FeaturePoint: \(feature_point)")
                featurePoints.append(feature_point)
            }
        }
        print("Number of featurePoints: \(featurePoints.count)")
    }
    
    func getViewportCoordinates(arView: ARSCNView, point: SIMD3<Float>) -> SCNVector3 {
        let scn_point = SCNVector3(point)
        let projected_point = arView.projectPoint(scn_point)
        return projected_point
    }
    
    func normalizeCoordinates(point: SCNVector3) -> SCNVector3 {
        let x_pixel = CGFloat(point.x) / UIScreen.main.bounds.width
        let y_pixel = CGFloat(point.y) / UIScreen.main.bounds.height
        //return SCNVector3(x: Float(x_pixel), y: Float(y_pixel), z: 0.0)
        return point
    }
    
    
    func getPointToCameraDistances(arCamera: ARCamera, point: SIMD3<Float>) -> SIMD4<Float> {
        // returns the distances from the camera (because we are setting the origin there) to the point in meters
        let viewMatrix = arCamera.viewMatrix(for: .landscapeLeft)
        // conversion to camera origin, units are in meters, negative means that point is below and to the left of the camera
        let points_from_camera = viewMatrix * SIMD4<Float>(point, 1)
        return points_from_camera
    }
    
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
