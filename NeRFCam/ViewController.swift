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
    @IBOutlet weak var gestureRecognizer: UITapGestureRecognizer!
    
    var isPressed: Bool = false
    var framesCapturedCount: Int = 0
    
    
    // collect camera data to send to API
    
    var projectionMatrixArr: Array<simd_float4x4> = []
    var intrinsicMatrixArr: Array<simd_float3x3> = []
    var capturedDataArr: Array<CapturedFrameData> = []
    var rawFeaturePointsArr: Array<FeaturePointsData> = []
    
//    var rawFeaturePointsCollection: [vector_float3] = []
//    var frameInformationArr: Array<FrameInformation> = []
    
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
        // TODO: Is this correct? It didn't change anything
        configuration.worldAlignment = ARConfiguration.WorldAlignment.camera
        
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
        print("Sender: \(sender)")
        let point: CGPoint = sender.location(in: view)
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
        
        // process all rawFeaturePoints for all cameras
//        let final_information: Array<FramePoints>
//        final_information = processRawFeaturePoints(frameInformationArr: frameInformationArr, rawFeaturePointsCollection: rawFeaturePointsCollection)
//        // encode the info in a json
//        let final_information_json_encoded = try? JSONEncoder().encode(final_information)
//        let final_information_data_filename = dataPath.appendingPathComponent("rawFeaturePointsData.json")
//        print(final_information_data_filename)
//        do {
//            try final_information_json_encoded?.write(to: final_information_data_filename)
//        } catch let error {
//            print(error.localizedDescription)
//        }
        
        //encode raw feature points data
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
    
//    func processRawFeaturePoints(frameInformationArr: Array<FrameInformation>, rawFeaturePointsCollection: [vector_float3]) -> Array<FramePoints> {
//        /**
//         Iterate through every camera, project the point cloud and only save the points that interesect with that camera plane
//         */
//        var finalInformationArr: Array<FramePoints> = []
//        print("Total number of rawFeaturePoints is: \(rawFeaturePointsCollection.count)")
//        for frameInformation in frameInformationArr {
//            print("View Matrix: \(frameInformation.view_matrix)")
//            let frame_slam_points = frameInformation.projectRawFeaturePointsToCamera(rawFeaturePoints: rawFeaturePointsCollection)
//            let final_information = FramePoints(slam_points: frame_slam_points, file_path: frameInformation.file_path)
//            print("Number of rawFeaturePoints for frame: \(frameInformation.file_path) is: \(final_information.slam_points.count)")
//            finalInformationArr.append(final_information)
//        }
//        return finalInformationArr
//
//
//    }
    
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
            let image = UIImage(pixelBuffer: frame.capturedImage)
            
            if let data = image?.jpegData(compressionQuality: 1.0 ) {
                let filename = dataPath.appendingPathComponent("frame\(framesCapturedCount).jpeg")
                
                // save frame
                try? data.write(to: filename)
                let capturedFrameData = CapturedFrameData(arFrame: frame, filename: "frame\(framesCapturedCount).jpeg")
                capturedDataArr.append(capturedFrameData)
                
                // save raw feature points
                let rawFeaturePoints = frame.rawFeaturePoints?.points
                if rawFeaturePoints != nil {
                    // collect all rawFeaturePoints for each frame in one array
//                    print("Number of rawFeaturePoints for frame \(framesCapturedCount) is: \(String(describing: rawFeaturePoints?.count))")
//                    rawFeaturePointsCollection.append(contentsOf: rawFeaturePoints ?? [])
//                    let frame_information = FrameInformation(arView: arView, arCamera: frame.camera, filePath: "frame\(framesCapturedCount).jpeg")
//
//                    frameInformationArr.append(frame_information)
                    
                    let featurePointData = FeaturePointsData(arView: arView, arCamera: frame.camera, rawFeaturePoints: rawFeaturePoints ?? [], filename: "frame\(framesCapturedCount).jpeg")
                    rawFeaturePointsArr.append(featurePointData)
                }
                
            }
            
            lastFrame = frame
            framesCapturedCount += 1
        }
        
    }

}
