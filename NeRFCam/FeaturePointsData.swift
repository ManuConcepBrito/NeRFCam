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
            let interfaceOrientation = arView.window?.windowScene?.interfaceOrientation
            let point_to_camera_distances = getPointToCameraDistances(arCamera: arCamera, point: point, orientation: interfaceOrientation ?? .landscapeLeft)
            // stay only with z, the distance from the point to the camera (negative) in meters
            // convert to a positive value and to milimiters
            let z = point_to_camera_distances.z * -1 * 1000
            // get the viewport coordinates for x and y, viewport for iPhone 13 is, for example: 390x 844
            let viewport_coords = getViewportCoordinates(arView: arView, point: point, arCamera: arCamera, orientation: interfaceOrientation ?? .landscapeLeft)
            // normalize the viewport coordinates for easier plotting in Python
            let viewport_coords_normalized = normalizeCoordinates(point: viewport_coords)
            // we need to filter negative values for x and y as it indicates that a point is projected outside of the view
            if (viewport_coords_normalized.x.sign == .plus && viewport_coords_normalized.y.sign == .plus) && (viewport_coords_normalized.x.isLess(than: 1.0) && viewport_coords_normalized.y.isLess(than: 1.0)) {
                let feature_point = FeaturePoint(x: viewport_coords_normalized.x, y: viewport_coords_normalized.y, z: z)
                featurePoints.append(feature_point)
            }
        }
        print("Number of featurePoints: \(featurePoints.count)")
    }
    
    func getViewportCoordinates(arView: ARSCNView, point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> SCNVector3 {
        let scn_point = SCNVector3(point)
        let projected_point = arView.projectPoint(scn_point)
        // debug
        
        //let one_var = arCamera.viewMatrix(for: orientation) * SIMD4<Float>(point, 1)
        //let another_var = SIMD3<Float>(one_var.x, one_var.y, one_var.z)
//        let projected_point_2 = arCamera.intrinsics * another_var
        //let projected_point_2 = arCamera.intrinsics * point
        let projectionMatrix = arCamera.projectionMatrix(for: orientation, viewportSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height), zNear: 0, zFar: 1000)
        let projected_point_2 = projectionMatrix * SIMD4<Float>(point, 1)
        print("Projected point: \(projected_point) and manually projected \(projected_point_2)")
        return projected_point
    }
    
    func normalizeCoordinates(point: SCNVector3) -> SCNVector3 {
        let x_pixel = CGFloat(point.x) / UIScreen.main.bounds.width
        let y_pixel = CGFloat(point.y) / UIScreen.main.bounds.height
        return SCNVector3(x: Float(x_pixel), y: Float(y_pixel), z: 0.0)
    }
    
    
    func getPointToCameraDistances(arCamera: ARCamera, point: SIMD3<Float>, orientation: UIInterfaceOrientation) -> SIMD4<Float> {
        // returns the distances from the camera (because we are setting the origin there) to the point in meters
        let viewMatrix = arCamera.viewMatrix(for: orientation)
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
