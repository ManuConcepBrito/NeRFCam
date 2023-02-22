# NeRFCam

Simple app to acquire camera extrinsics, intrinsics and [rawFeaturePoints](https://developer.apple.com/documentation/arkit/arframe/2887449-rawfeaturepoints) using Apple's ARKit.

**Important**: Use the app only in Landscape (left) mode, due to how the images are acquired, the correct feature points are exported only while using landscape left mode. More info [here](https://developer.apple.com/documentation/uikit/uiimage/orientation)

Usage Instructions:
- Press "Capture" to acquire one frame
- Press "Save Data" to save all the captured frames to memory.

The saved data is in the files app -> NERFCam -> Folder with the timestamp that the capture started. The data consists of:

- All captured frames (naming is frame_%05d.jpeg)
- A transforms.json following the nerfstudio data format. See [here](https://docs.nerf.studio/en/latest/quickstart/data_conventions.html)
- A rawFeaturePoints.json (in millimiters and +Z) with the feature points for each frame with format:
```
[{"file_path": "frame_00001.jpeg", 
  "featurePoints": [{"x": 408.92, "y": 245.83, "z": 265.33}, 
                    {"x": 410.12, "y": 122.2, "z": 131.33}, 
                    ...}]
```

![IMG_50454AE3D3F3-1](https://user-images.githubusercontent.com/33829944/220628037-c075ca9d-4819-49ee-bc76-d203d6fc3cb5.jpeg)
