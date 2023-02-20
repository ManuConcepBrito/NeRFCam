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
        /** Rotate Point counterclockwise around the center of the image.
         See https://stackoverflow.com/questions/2259476/rotating-a-point-about-another-point-2d
             Angle is in radians
         */
        
        // image center as (0,0). Translate points to the middle.
        let x_middle = x - 1920.0/2
        let y_middle = y - 1440.0/2
        
        // rotate point
        let s = sinf(angle)
        let c = cosf(angle)
        
        let x_middle_rot = c * x_middle - s * y_middle
        let y_middle_rot = s * x_middle + c * y_middle
        
        // translate the point back to the image coordinate system
        let x_rot = x_middle_rot + 1920.0/2
        let y_rot = y_middle_rot + 1440.0/2
        

        return SIMD2(x_rot, y_rot)
    }

    func translatePoint(x: Float, y: Float, width: Float, height: Float) -> SIMD2<Float> {
        
        return SIMD2(width - x, height - y)
    }
    
    func useCameraTransform(point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> SIMD3<Float> {
        let pointProjected = arCamera.transform * SIMD4<Float>(point, 1)
        let homogenousImageSpacePosition = arCamera.intrinsics * pointProjected[SIMD3(0,1,2)]
        return homogenousImageSpacePosition / homogenousImageSpacePosition.z
    }
    
    func useViewMatrix(point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> SIMD3<Float> {
//        let viewMatrix = arCamera.viewMatrix(for: orientation)
//        let projectedPoint = viewMatrix * SIMD4<Float>(point, 1)
//        let projectedPointNormalized = (projectedPoint / projectedPoint.w)[SIMD3(0,1,2)]
        
        let projectedPoint = arCamera.transform.inverse * SIMD4<Float>(point, 1)
        
        print("Projected point: \(projectedPoint)")
        
        let projectedPointNormalized = (projectedPoint / projectedPoint.w)[SIMD3(0,1,2)]
        
        let homogenousImageSpacePosition = arCamera.intrinsics * projectedPointNormalized
        
        let euclidianImageSpacePosition = homogenousImageSpacePosition / homogenousImageSpacePosition.z
        
        return euclidianImageSpacePosition
    }
    
    func useProjectionMatrix(point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> SIMD3<Float> {
        let projectedPoint = arCamera.projectionMatrix * SIMD4<Float>(point, 1)
        let projectedPoint2 = projectedPoint / projectedPoint.w
        let projectedPoint3 = projectedPoint2 / projectedPoint2.z
        print("Projected point: \(projectedPoint3)")
        
        return projectedPoint3[SIMD3(0,1,2)]
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        
        if isPressed {
            isPressed = false
            infoText.text = "Frames Captured: \(framesCapturedCount + 1)"
            let rawFeaturePoints2 = frame.rawFeaturePoints?.points
            compositedImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let _orientationTransform = compositedImage.orientationTransform(for: .right)
            compositedImage = compositedImage.transformed(by: _orientationTransform)
                        
            for point in rawFeaturePoints2 ?? [] {

                
                let interfaceOrientation = arView.window?.windowScene?.interfaceOrientation
                
                let euclidianImageSpacePosition = useViewMatrix(point: SIMD3<Float>(point), arCamera: frame.camera, orientation: interfaceOrientation ?? .landscapeLeft)
                
                let translatedPoint = translatePoint(x: euclidianImageSpacePosition.x, y: euclidianImageSpacePosition.y, width: Float(frame.camera.imageResolution.width), height: Float(frame.camera.imageResolution.height))
                                
                // Used to match the rotate the featurePoints in the same way the image
                // See https://developer.apple.com/documentation/corefoundation/cgaffinetransform
                
                let x = Float(_orientationTransform.a) * translatedPoint.x + Float(_orientationTransform.c) * translatedPoint.y + Float(_orientationTransform.tx)
                let y = Float(_orientationTransform.b) * translatedPoint.x + Float(_orientationTransform.d) * translatedPoint.y + Float(_orientationTransform.ty)
                
               
                // The if condition is a bit confusing, but it is correct.
                // The ImageView is 1920x1440 however, we are plotting on top of it an image that is 1440x1920
                // if you check (0...1920).contains(x) && (0...1440).contains(y) you will end up with some feature points outside of the image
                if (0...Float(frame.camera.imageResolution.width)).contains(y) && (0...Float(frame.camera.imageResolution.height)).contains(x) {
                    
                    debugImage = CIImage(color: .red).cropped(to: .init(origin: CGPoint(x: CGFloat(x), y: CGFloat(y)),
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
