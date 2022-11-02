//
//  ViewController.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 29/10/22.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

   
    
    @IBOutlet weak var CaptureButton: UIButton!
    @IBOutlet weak var infoText: UILabel!
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var parentView: UIView!
    
    var isPressed: Bool = false
    var framesCapturedCount: Int = 0
    let framesNeededForNeRF: Int = 3
    
    // collect camera data to send to API
    
    var projectionMatrixArr: [simd_float4x4] = Array(repeating: simd_float4x4(), count: 20)
    var intrinsicMatrixArr: [simd_float3x3] = Array(repeating: simd_float3x3(), count: 20)
    //<ARFrame: 0x100b63bb0 timestamp=123957.421347 capturedImage=0x282e34d10 camera=0x2825b0100 lightEstimate=0x2819a2260 | 1 anchor, 20 features>


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    }
    
    /// - Tag: StartARSession
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Start the view's AR session with a configuration that uses the rear camera,
        // device position and orientation tracking, and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        arView.session.run(configuration)

        // Set a delegate to track the number of plane anchors for providing UI feedback.
        arView.session.delegate = self
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
        arView.showsStatistics = true
        
    }
    
    @IBAction func captureFrame(_ sender: Any) {
        isPressed = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's AR session.
        arView.session.pause()
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isPressed {
            isPressed = false
            projectionMatrixArr[framesCapturedCount] = frame.camera.projectionMatrix
            intrinsicMatrixArr[framesCapturedCount] = frame.camera.intrinsics
            framesCapturedCount += 1
            infoText.text = "Frames Captured: \(framesCapturedCount)/\(framesNeededForNeRF)"
        }
        if framesCapturedCount == framesNeededForNeRF {
            print("Hey")
        }
        
    }

}
