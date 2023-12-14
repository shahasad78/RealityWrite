//
//  ContentView.swift
//  RealityWritePoC
//
//  Created by Shah Martinez on 12/13/23.
//
import SwiftUI
import RealityKit
import ARKit
import CoreML
import Vision


// create an Observable object that structs can access
class ModelRecognizer: ObservableObject {
    private init() {}
    
    static let shared = ModelRecognizer()
    
    @Published var arView = ARView()
    @Published var recognizedObject = "No objects recognized"
    
    // instantiate CoreML model
    @Published var model = try! VNCoreMLModel(for: MobileNetV2().model)
    
    // constantly poll the AR session for frames to submit to ML Model.
    // but not too fast so we don't tax the CPU
    var timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        continuouslyUpdate()
    }
    
    func setRecognizedObject(newObject: String) {
        recognizedObject = newObject
    }
}


struct ContentView : View {
    var body: some View {
        Text(verbatim: "Hold phone in portrait mode")
        WrappingView()
    }
}

struct WrappingView: View {
    @ObservedObject var recognizedObj: ModelRecognizer = .shared
    
    var body: some View {
        ZStack {
            ARViewContainer().edgesIgnoringSafeArea(.all)
        }
    }
    
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        @ObservedObject var recognizedObj: ModelRecognizer = .shared
        return recognizedObj.arView
        
//        let arView = ARView(frame: .zero)
//
//        // Create a cube model
//        let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
//        let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: true)
//        let model = ModelEntity(mesh: mesh, materials: [material])
//        model.transform.translation.y = 0.05
//
//        // Create horizontal plane anchor for the content
//        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))
//        anchor.children.append(model)
//
//        // Add the horizontal plane anchor to the scene
//        arView.scene.anchors.append(anchor)
//
//        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

func continuouslyUpdate() {
    @ObservedObject var recognizedObject: ModelRecognizer = .shared
    
    // access the information from the observed object
    let arView = recognizedObject.arView
    let session = arView.session
    let model = recognizedObject.model
    
    // access the current frame as an image
    let tempImage: CVPixelBuffer? = session.currentFrame?.capturedImage
    
    // get the current camera frame from the live AR session
    if tempImage == nil {
        return
    }
    
    let tempCIImage = CIImage(cvPixelBuffer: tempImage!)
    
    // create a request to the Vision CoreML model
    let request = VNCoreMLRequest(model: model) { (request, error) in }
    
    // crop the center of the captured frame to send to ML model
    request.imageCropAndScaleOption = .centerCrop
    
    // perform the request
    let requestHandler = VNImageRequestHandler(ciImage: tempCIImage, orientation: .right)
    
    do {
        try requestHandler.perform([request])
    } catch {
        print(error)
    }
    
    guard let observations = request.results as? [VNClassificationObservation] else { return }
    
    // only proceed if the model is more than 50% confident of the result
    if observations[0].confidence < 0.5 { return }
    
    // the model returns predictions in descending order of confidence
    // take the first prediction, which is the one with the highest confidence
    let topObservation = observations[0].identifier
    
    let firstWord = topObservation.components(separatedBy: ",")[0]
    
    // Let's only set the recognized object if it hasn't been set before
    // we can change this when we start recognizing multiple objects
    if recognizedObject.recognizedObject != firstWord {
        DispatchQueue.main.async {
            recognizedObject.setRecognizedObject(newObject: firstWord)
        }
    }
}

// TODO: finish implementation
func generate3DLabel(forWord: String) -> SCNText {
    // Generate a 3D label to place on the anchor
    return SCNText()
}

#Preview {
    ContentView()
}
