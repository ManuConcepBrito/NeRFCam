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
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var gestureRecognizer: UITapGestureRecognizer!
    
    var isPressed: Bool = false
    var framesCapturedCount: Int = 0
    
    
    // collect camera data to send to API
    
    var projectionMatrixArr: Array<simd_float4x4> = []
    var intrinsicMatrixArr: Array<simd_float3x3> = []
    var capturedDataArr: Array<CapturedFrameData> = []
    var rawFeaturePointsArr: Array<FeaturePointsData> = []
    // hack to get the last intrinsics, just as POC to try out NerfStudio
    var lastFrame: ARFrame!
    //<ARFrame: 0x100b63bb0 timestamp=123957.421347 capturedImage=0x282e34d10 camera=0x2825b0100 lightEstimate=0x2819a2260 | 1 anchor, 20 features>
    
    var dataPath: URL!
    
    var compositedImage: CIImage!
    var debugImage: CIImage!


    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
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
        configuration.worldAlignment = .camera
        
        configuration.planeDetection = [.horizontal, .vertical]

        arView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
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
    
    @IBAction func myActionMethod(_ sender: UIGestureRecognizer) {
        let point: CGPoint = sender.location(in: arView)
        print(point)
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
        
        // encode raw feature points data
        let rawFeaturePointsData = try? JSONEncoder().encode(rawFeaturePointsArr)
        let rawFeaturePointsDataFilename = dataPath.appendingPathComponent("rawFeaturePointsData.json")
        print(rawFeaturePointsDataFilename)
        do {
            try rawFeaturePointsData?.write(to: rawFeaturePointsDataFilename)
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
    
    func rotatePoint(x: Float, y: Float, angle: Float) -> SIMD2<Float>{
        let s = sinf(angle)
        let c = cosf(angle)
        print("Cosine and sine: \(c) \(s)")
        
        return SIMD2(c * x - s * y, s * x + c * y)
    }
    func translatePoint(x: Float, y: Float) -> SIMD2<Float> {
        
        return SIMD2(1920 - x, 1440 - y)
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        
        if isPressed {
            isPressed = false
            infoText.text = "Frames Captured: \(framesCapturedCount + 1)"
            let rawFeaturePoints2 = frame.rawFeaturePoints?.points
            compositedImage = CIImage(cvPixelBuffer: frame.capturedImage)

            
            for point in rawFeaturePoints2 ?? [] {
                let homogenousImageSpacePosition = frame.camera.intrinsics * SIMD3<Float>(point)
                
                // Divides all components of the homogenous coordinate by the last component to get the euclidian coordinate.
                let euclidianImageSpacePosition = homogenousImageSpacePosition / homogenousImageSpacePosition.z
                                
                let translatedPoint = translatePoint(x: euclidianImageSpacePosition.x, y: euclidianImageSpacePosition.y)
                
                
                if (0...1920).contains(translatedPoint.x) && (0...1440).contains(translatedPoint.y) {
                    print("translatedPoint Point: \(translatedPoint)")
                    
                    
                    debugImage = CIImage(color: .red).cropped(to: .init(origin: CGPoint(x: CGFloat(translatedPoint.x), y: CGFloat(translatedPoint.y)),
                                                                        size: .init(width: 20, height: 20)))

                    compositedImage = debugImage.composited(over: compositedImage)
                }
                
            }
            DispatchQueue.main.async { [unowned self] in
                imageView.image = UIImage(ciImage: compositedImage)
            }
        }
        
    }

}
