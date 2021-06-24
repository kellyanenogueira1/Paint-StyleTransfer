//
//  ViewController.swift
//  Paint
//
//  Created by Kellyane Nogueira on 18/06/21.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let config = MLModelConfiguration()
    let imageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupImage()
        accessCamera()
    }
    
    func setupImage() {
        view.addSubview(imageView)
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    func configureSession() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.medium
        
//        captureSession.beginConfiguration()
        
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        
        do {
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            print(error.localizedDescription)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        let photoOutput = AVCapturePhotoOutput()
        
        videoOutput.alwaysDiscardsLateVideoFrames = true //property ensures that frames arrive late are dropped, thereby ensuring there's less latency.
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
//        if captureSession.canAddOutput(photoOutput) {
//            captureSession.addOutput(photoOutput)
//        }
//
//        captureSession.commitConfiguration()
        
        guard let connection = videoOutput.connection(with: .video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        
        connection.videoOrientation = .portrait
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
       // previewLayer.frame = self.view.frame //
        //previewLayer.videoGravity = .resizeAspectFill //
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
    }
    
    func accessCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureSession()
            
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.configureSession()
                    }
                }
            
            case .denied:
                print("Denied")

            case .restricted: // The user can't grant access due to restrictions.
                print("Restricted")
                
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let model = try? VNCoreMLModel(for: MyPaintStyleTransferIteration1000.init(configuration: config).model) else { return }
        
        let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
            guard let results = finishedRequest.results as? [VNPixelBufferObservation] else { return }

            guard let observation = results.first else { return }

            DispatchQueue.main.async(execute: {
                self.imageView.image = UIImage(pixelBuffer: observation.pixelBuffer)
            })
        }

        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
}

