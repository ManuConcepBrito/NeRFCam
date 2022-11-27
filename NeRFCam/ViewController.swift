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
    
    var projectionMatrixArr: Array<simd_float4x4> = []
    var intrinsicMatrixArr: Array<simd_float3x3> = []
    var capturedDataArr: Array<CapturedFrameData> = []
    // hack to get the last intrinsics, just as POC to try out NerfStudio
    var lastFrame: ARFrame!
    //<ARFrame: 0x100b63bb0 timestamp=123957.421347 capturedImage=0x282e34d10 camera=0x2825b0100 lightEstimate=0x2819a2260 | 1 anchor, 20 features>
    
    var dataPath: URL!


    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    /// - Tag: StartARSession
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // clean state if the user goes back
        framesCapturedCount = 0
        projectionMatrixArr = []
        intrinsicMatrixArr = []
        print("I am executing and frames are: \(framesCapturedCount)")
        infoText.text = "Frames Captured: \(framesCapturedCount)"
        
        // Create folder to save the data
        
        dataPath = createFolder()
        
        // Do any additional setup after loading the view.
        

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
        let jsonFilename = dataPath.appendingPathComponent("transforms.json")
        print(jsonFilename)
        do {
            try encodedData?.write(to: jsonFilename)
        } catch let error {
            print(error.localizedDescription)
        }
       
        
        
        
        
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
    
    func createFolder() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(fileURLWithPath: documentsDirectory)
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd_MM_yyyy'T'HH_mm_ss"
        let finalPath = docURL.appendingPathComponent(dateFormatter.string(from: date))
        
        do {
            try FileManager.default.createDirectory(atPath: finalPath.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating folder: \(error.localizedDescription)")
        }
        return finalPath
        
    }
    
  

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isPressed {
            isPressed = false
            infoText.text = "Frames Captured: \(framesCapturedCount + 1)"
            // save image data
            //let image = UIImage(pixelBuffer: frame.get)
            let image = frame.getCapturedImage(inSceneView: arView)
            
            let height = image!.size.height * (image?.scale ?? 0)!
            let width = image!.size.width * (image?.scale ?? 0)!
            
            print("size:")
            print(height)
            print(width)
            
            if let data = image?.jpegData(compressionQuality: 1.0 ) {
                let filename = dataPath.appendingPathComponent("frame\(framesCapturedCount).jpeg")
                try? data.write(to: filename)
                let capturedFrameData = CapturedFrameData(arFrame: frame, width: width, height: height, filename: "frame\(framesCapturedCount).jpeg")
                capturedDataArr.append(capturedFrameData)
            }
            
            lastFrame = frame
            framesCapturedCount += 1
        }
        
    }

}
