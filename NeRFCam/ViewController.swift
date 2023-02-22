//
//  ViewController.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 29/10/22.
//

import UIKit
import CoreImage
import SceneKit
import ARKit
import UniformTypeIdentifiers

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
    var context: CIContext!
    
    var dataPath: URL!
    
    var compositedImage: CIImage!
    var debugImage: CIImage!


    override func viewDidLoad() {
        super.viewDidLoad()
        context = CIContext()
        
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
    

    func translatePoint(x: Float, y: Float, width: Float, height: Float) -> SIMD2<Float> {
        
        return SIMD2(width - x, height - y)
    }
    
    func projectPoint(point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> FeaturePoint {
        // Project Point from 3D World to 3D Camera Space
        let projectedPoint = arCamera.transform.inverse * SIMD4<Float>(point, 1)
        
        // distance from the camera in millimiters (positive away from the camera)
        let depth = projectedPoint.z * -1 * 1000
        
        // Convert to 3x1 Array, fourth component is 1
        let projectedPointNormalized = (projectedPoint / projectedPoint.w)[SIMD3(0,1,2)]
        
        // Convert to 2D Image Space
        let homogenousImageSpacePosition = arCamera.intrinsics * projectedPointNormalized
        
        let euclidianImageSpacePosition = homogenousImageSpacePosition / homogenousImageSpacePosition.z
        
        let featurePoint = FeaturePoint(x: euclidianImageSpacePosition.x, y: euclidianImageSpacePosition.y, z: depth)
        
        return featurePoint
    }
    
    func processPoint(point: SIMD3<Float>, arCamera: ARCamera, orientation: UIInterfaceOrientation) -> FeaturePoint {
        /**
         Project one feature point in the correct coordinate system to be plotted on top of the captured images
         */
        let euclidianImageSpacePosition = projectPoint(point: SIMD3<Float>(point), arCamera: arCamera, orientation:  orientation)
        let translatedPoint = translatePoint(x: euclidianImageSpacePosition.x, y: euclidianImageSpacePosition.y, width: Float(arCamera.imageResolution.width), height: Float(arCamera.imageResolution.height))

        
        return FeaturePoint(x: translatedPoint.x, y: translatedPoint.y, z: euclidianImageSpacePosition.z)
    }
    
    func saveImage(capturedImage: CVPixelBuffer) -> Bool {
        // rotate image to match the view of ARKit
        let capturedFrame = CIImage(cvPixelBuffer: capturedImage)
        
        // createa a CGImage
        let cgImage = context.createCGImage(capturedFrame, from: capturedFrame.extent)!
        let image = UIImage(cgImage: cgImage)
        
        if let data = image.jpegData(compressionQuality: 1.0) {
            let filename = dataPath.appendingPathComponent(String(format: "frame_%05d.jpeg", framesCapturedCount+1))
            do {
                try data.write(to: filename)
                return true
            } catch {
                return false
            }
        }
        return false
    }
    

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        
        if isPressed {
            isPressed = false
            infoText.text = "Frames Captured: \(framesCapturedCount + 1)"
            let rawFeaturePoints = frame.rawFeaturePoints?.points
            
            // Debug image needs to be rotated to match the view of ARKit. See: https://developer.apple.com/documentation/uikit/uiimage/orientation
            compositedImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let _orientationTransform = compositedImage.orientationTransform(for: .right)
            //compositedImage = compositedImage.transformed(by: _orientationTransform)
            let filename = String(format: "frame_%05d.jpeg", framesCapturedCount + 1)
            var featurePointsData = FeaturePointsData(file_path: filename)
            
            let successSavingImage = saveImage(capturedImage: frame.capturedImage)
            // if image cannot be saved or there are no feature points in this image, skip, don't process points
            if successSavingImage && rawFeaturePoints?.count ?? 0 > 0 {
                // save image and camera intrinsics, extrinsics
                let capturedFrameData = CapturedFrameData(arFrame: frame, filename: filename)
                capturedDataArr.append(capturedFrameData)
                
                // process feature points
                for point in rawFeaturePoints ?? [] {

                    let interfaceOrientation = arView.window?.windowScene?.interfaceOrientation
                    
                    let processedPoint = processPoint(point: point, arCamera: frame.camera, orientation: interfaceOrientation ?? .landscapeLeft)
                    let x = processedPoint.x
                    let y = processedPoint.y
                    
                    
                    if (0...Float(frame.camera.imageResolution.width)).contains(x) && (0...Float(frame.camera.imageResolution.height)).contains(y) {
                        
                        // Debug Image has the origin in the bottom left, python normally reads the images from top-left, correct that when exporting
                        let featurePoint = FeaturePoint(x: processedPoint.x, y: Float(frame.camera.imageResolution.height) - processedPoint.y, z: processedPoint.z)
                        featurePointsData.featurePoints.append(featurePoint)
                        // add the feature point to properly debug the projections
                        debugImage = CIImage(color: .red).cropped(to: .init(origin: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                                                                            size: .init(width: 20, height: 20)))
                        compositedImage = debugImage.composited(over: compositedImage)
                    }
                    
                }
                
                // append all feature points of one frame to the global variable containing all info for all frames
                rawFeaturePointsArr.append(featurePointsData)
                
                // update debug visualization with new featurePoints for captured frame
                DispatchQueue.main.async { [unowned self] in
                    imageView.image = UIImage(ciImage: compositedImage)
                }
                lastFrame = frame
                framesCapturedCount += 1
                
            }
            
        }
        
    }

}
