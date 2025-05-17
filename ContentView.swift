
import Vision
import CoreML
import AVFoundation
import SwiftUI


import MapKit
import CoreLocation
import Combine
import AVFoundation



struct ContentView: View {
    enum VistaActiva {
        case mapa
        case camara
    }
    
    @State private var vistaActiva: VistaActiva = .mapa
    @State private var mostrarInstrucciones: Bool = true
    @State private var decirPies: String = ""
    @State private var giro: String = ""
    
    var body: some View {
        ZStack {
            // Vista principal dinámica
            Group {
                if vistaActiva == .camara {
                    CameraView()
                        .edgesIgnoringSafeArea(.all)
                } else {
                    // Este contenedor será base para destinos y asistente
                    ZStack {
                        MapViewRepresentable()
                            .edgesIgnoringSafeArea(.all)
                        // Aquí puedes agregar vistas superpuestas específicas
                    }
                }
            }
            
            // 🟨 POPUP flotante con instrucciones
            if mostrarInstrucciones {
                VStack {
                    VStack(spacing: 10) {
                        HStack {
                            VStack(spacing: 10) {
                                HStack {
                                    if giro.contains("izquierda") {
                                        Image(systemName: "arrow.turn.up.left")
                                            .foregroundColor(.white)
                                    } else if giro.contains("derecha") {
                                        Image(systemName: "arrow.turn.up.right")
                                            .foregroundColor(.white)
                                    } else if giro.contains("adelante") {
                                        Image(systemName: "arrow.up")
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "arrow.2.circlepath")
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(giro.isEmpty ? "Espera a la instrucción de giro" : giro)
                                        .font(.body)
                                        .foregroundColor(.black)
                                        .padding(10)
                                        .background(Color.yellow)
                                        .cornerRadius(20)
                                }
                                HStack {
                                    Image(systemName: "shoeprints.fill")
                                        .foregroundColor(.white)
                                    
                                    Text(decirPies.isEmpty ? "Espera a los pies calculados" : decirPies)
                                        .font(.body)
                                        .foregroundColor(.black)
                                        .padding(10)
                                        .background(Color.yellow)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                        .background(Color.black)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                        .padding(.top, 30)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: mostrarInstrucciones)
                }
                
                // 🔻 Barra inferior con botones
                VStack {
                    Spacer()
                    
                    ZStack {
                        // Fondo negro que cubre todo el ancho hasta el borde inferior
                        Color.black
                            .ignoresSafeArea(edges: .bottom) // ⬅️ Esto asegura que el fondo llegue hasta abajo
                        
                        // Botones centrados
                        HStack(spacing: 60) {
                            Button(action: {
                                vistaActiva = .camara
                            }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                    Text("Cámara")
                                }
                                .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                vistaActiva = .mapa
                            }) {
                                VStack {
                                    Image(systemName: "map.fill")
                                    Text("Destinos")
                                }
                                .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                vistaActiva = .mapa
                            }) {
                                VStack {
                                    Image(systemName: "person.wave.2.fill")
                                    Text("Asistente")
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: 350)
                    }
                    .frame(height: 90) // Altura fija de la barra
                }
            }
        }
    }
}








































struct MapViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.mapType = .satellite
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
}





//MARK: - CAMARA
struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        let speechSynthesizer = AVSpeechSynthesizer()
        var lastSpokenLabel: String?

        
        
        /// Dice SOLAMENTE estas etiquetas
        let etiquetasPermitidas: Set<String> = ["person", "car", "chair", "cat", "dog"]

        /// Traduce del inglés al español las etiquetas
        let traducciones: [String: String] = [
            "person": "persona",
            "car": "carro",
            "chair": "silla",
            "cat": "gato",
            "dog": "perro"
        ]

        /// Indica el género de la palabra en español
        let generos: [String: String] = [
            "persona": "f", // femenino
            "carro": "m",   // masculino
            "silla": "f",
            "gato": "m",
            "perro": "m"
        ]
        
        override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
        }

        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession.sessionPreset = .high
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("No se pudo acceder a la cámara")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
                
                let output = AVCaptureVideoDataOutput()
                output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if captureSession.canAddOutput(output) {
                    captureSession.addOutput(output)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.layer.bounds
                view.layer.addSublayer(previewLayer)

                DispatchQueue.global(qos: .background).async {
                    self.captureSession.startRunning()
                }
                
            } catch {
                print("Error al configurar la cámara: \(error)")
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let observations = ObjectDetector.shared.detectObjects(pixelBuffer: pixelBuffer)
                DispatchQueue.main.async {
                    self.drawBoundingBoxes(for: observations)
                    self.announceDetectedObjects(observations)
                }
            }
        }

        func drawBoundingBoxes(for observations: [VNRecognizedObjectObservation]) {
            DispatchQueue.main.async {
                self.view.layer.sublayers?.removeSubrange(1...)
            }
            
            for observation in observations {
                guard let label = observation.labels.first?.identifier,
                      etiquetasPermitidas.contains(label) else { continue }

                let boundingBox = observation.boundingBox
                
                let frame = CGRect(
                    x: boundingBox.origin.x * self.view.frame.width,
                    y: (1 - boundingBox.origin.y - boundingBox.height) * self.view.frame.height,
                    width: boundingBox.width * self.view.frame.width,
                    height: boundingBox.height * self.view.frame.height
                )

                let boxLayer = CALayer()
                boxLayer.frame = frame
                boxLayer.borderColor = UIColor.red.cgColor
                boxLayer.borderWidth = 2.0

                let textLayer = CATextLayer()
                let etiquetaTraducida = traducciones[label] ?? label
                textLayer.string = etiquetaTraducida.capitalized
                textLayer.foregroundColor = UIColor.white.cgColor
                textLayer.fontSize = 14
                textLayer.frame = CGRect(x: frame.origin.x, y: frame.origin.y - 20, width: frame.width, height: 20)
                textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                textLayer.alignmentMode = .center

                DispatchQueue.main.async {
                    self.view.layer.addSublayer(boxLayer)
                    self.view.layer.addSublayer(textLayer)
                }
            }
        }

        
        ///Anuncia los objetos detectados en español
        func announceDetectedObjects(_ observations: [VNRecognizedObjectObservation]) {
            // Si no hay ninguna etiqueta permitida en la imagen, no decimos nada
            guard let observation = observations.first(where: { etiquetasPermitidas.contains($0.labels.first?.identifier ?? "") }) else {
                lastSpokenLabel = nil
                return
            }

            let originalLabel = observation.labels.first?.identifier ?? "Desconocido"
            
            guard etiquetasPermitidas.contains(originalLabel) else { return }

            let translatedLabel = traducciones[originalLabel] ?? originalLabel
            let genero = generos[translatedLabel] ?? "m"
            let articulo = (genero == "f") ? "una" : "un"

            let mensaje = "Tienes \(articulo) \(translatedLabel) al frente"

            // 👉 Siempre que haya un box, se va a decir en voz alta, sin importar si es repetido
            let utterance = AVSpeechUtterance(string: mensaje)
            utterance.voice = AVSpeechSynthesisVoice(language: "es-US")
            utterance.rate = 0.5

            // Detenemos lo anterior si sigue hablando (opcional, puedes comentar esta línea si prefieres que se sobrepongan)
            if speechSynthesizer.isSpeaking {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }

            speechSynthesizer.speak(utterance)
            lastSpokenLabel = translatedLabel
        }

    }
}



//MARK: - YOLO
class ObjectDetector {
    static let shared = ObjectDetector()
    private var model: VNCoreMLModel?

    private init() {
        guard let mlModel = try? YOLOv3(configuration: .init()).model,
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            print("Error al cargar el modelo ML")
            return
        }
        self.model = visionModel
    }
    
    /// Dice SOLAMENTE estas etiquetas
    let etiquetasPermitidas: Set<String> = ["person", "car", "chair", "cat", "dog"]

    /// Traduce del inglés al español las etiquetas
    let traducciones: [String: String] = [
        "person": "persona",
        "car": "carro",
        "chair": "silla",
        "cat": "gato",
        "dog": "perro"
    ]

    /// Indica el género de la palabra en español
    let generos: [String: String] = [
        "persona": "f", // femenino
        "carro": "m",   // masculino
        "silla": "f",
        "gato": "m",
        "perro": "m"
    ]
    
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNRecognizedObjectObservation] {
        guard let model = self.model else { return [] }
        
        let request = VNCoreMLRequest(model: model)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            let results = request.results as? [VNRecognizedObjectObservation] ?? []

            /// Solo devuelve resultados filtrados por etiquetasPermitidas
            let filteredResults = results.filter { result in
                guard let label = result.labels.first?.identifier else { return false }
                return etiquetasPermitidas.contains(label)
            }

            return filteredResults
        } catch {
            print("Error al procesar la imagen: \(error)")
            return []
        }
    }
}
