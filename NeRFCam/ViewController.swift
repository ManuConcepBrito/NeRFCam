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

    
    @IBOutlet var nextButton: UIButton!
    @IBOutlet weak var CaptureButton: UIButton!
    @IBOutlet weak var infoText: UILabel!
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var parentView: UIView!
    
    var isPressed: Bool = false
    var framesCapturedCount: Int = 0
    
    
    // collect camera data to send to API
    
    var projectionMatrixArr: [simd_float4x4] = Array(repeating: simd_float4x4(), count: 20)
    var intrinsicMatrixArr: [simd_float3x3] = Array(repeating: simd_float3x3(), count: 20)
    var capturedDataArr: Array<CapturedFrameData> = []
    // hack to get the last intrinsics, just as POC to try out NerfStudio
    var lastFrame: ARFrame!
    //<ARFrame: 0x100b63bb0 timestamp=123957.421347 capturedImage=0x282e34d10 camera=0x2825b0100 lightEstimate=0x2819a2260 | 1 anchor, 20 features>


    override func viewDidLoad() {
        super.viewDidLoad()
        infoText.text = "Frames Captured: \(framesCapturedCount)"
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
   
    @IBAction func sendNext(_ sender: UIButton) {
        let nerfData = NeRFData(capturedFrameData: capturedDataArr, arFrame: lastFrame)
        let encodedData = try? JSONEncoder().encode(nerfData)
        let jsonFilename = getDocumentsDirectory().appendingPathComponent("transforms.json")
        try? encodedData?.write(to: jsonFilename)
        
        // navigate to next screen
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let vc =  storyBoard.instantiateViewController(withIdentifier: "SendDataViewController") as! SendDataViewController
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's AR session.
        arView.session.pause()
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
  

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isPressed {
            isPressed = false
            infoText.text = "Frames Captured: \(framesCapturedCount + 1)"
            // save image data
            let image = UIImage(pixelBuffer: frame.capturedImage)
            
            if let data = image?.jpegData(compressionQuality: 1.0 ) {
                let filename = getDocumentsDirectory().appendingPathComponent("frame\(framesCapturedCount).jpeg")
                try? data.write(to: filename)
                let capturedFrameData = CapturedFrameData(arFrame: frame, filename: "frame\(framesCapturedCount).jpeg")
                capturedDataArr.append(capturedFrameData)
            }
            
            lastFrame = frame
            framesCapturedCount += 1
        }
        
    }

}
