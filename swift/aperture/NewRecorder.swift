//
//  ViewController.swift
//  CustomCamera
//
//  Created by Taras Chernyshenko on 6/27/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//
import AVFoundation
import Photos

class NewRecorder: NSObject,
  AVCaptureAudioDataOutputSampleBufferDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate {
  
  private var session: AVCaptureSession = AVCaptureSession()
  private var deviceInput: AVCaptureScreenInput?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
  private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
  
  private var audioConnection: AVCaptureConnection?
  private var videoConnection: AVCaptureConnection?
  
  private var assetWriter: AVAssetWriter?
  private var audioInput: AVAssetWriterInput?
  private var videoInput: AVAssetWriterInput?
  
  private var fileManager: FileManager = FileManager()
  
  private var isRecordingSessionStarted: Bool = false
  
  private var destinationUrl: URL
  private var fps: Int
  private var showCursor: Bool
  private var highlightClicks: Bool
  private var displayId: CGDirectDisplayID
  private var audioDevice: AVCaptureDevice?
  private var videoCodec: String?
  private var width: Int
  private var height: Int
  private var audioBitrate: Int
  private var videoBitrate: Int
  
  var onStart: (() -> Void)?
  var onFinish: (() -> Void)?
  var onError: ((Error) -> Void)?
  var onPause: (() -> Void)?
  var onResume: (() -> Void)?
  
  private var recordingQueue = DispatchQueue(label: "recording.queue")
  
  init(destination: URL, fps: Int, cropRect: CGRect?, showCursor: Bool, highlightClicks: Bool, displayId: CGDirectDisplayID = CGMainDisplayID(), audioDevice: AVCaptureDevice? = .default(for: .audio), videoCodec: String = "avc1", width: Int, height: Int, audioBitrate: Int, videoBitrate: Int) {
 
    self.destinationUrl = destination
    self.fps = fps
    self.showCursor = showCursor
    self.highlightClicks = highlightClicks
    self.displayId = displayId
    self.audioDevice = audioDevice!
    self.videoCodec = videoCodec
    self.width = width
    self.height = height
    self.audioBitrate = audioBitrate
    self.videoBitrate = videoBitrate
  }
 
  func setup() {
    self.session.sessionPreset = AVCaptureSession.Preset.high
  
    if self.fileManager.isDeletableFile(atPath: self.destinationUrl.path) {
      _ = try? self.fileManager.removeItem(atPath: self.destinationUrl.path)
    }
    
    self.assetWriter = try? AVAssetWriter(outputURL: self.destinationUrl,
                                          fileType: AVFileType.mp4)
    self.assetWriter!.movieFragmentInterval = kCMTimeInvalid
    self.assetWriter!.shouldOptimizeForNetworkUse = true
    
    let audioSettings = [
      AVFormatIDKey : kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey : 2,
      AVSampleRateKey : 44100.0,
      AVEncoderBitRateKey: self.audioBitrate
      ] as [String : Any]
    
    
    
     let videoSettings = [
      AVVideoCodecKey : self.videoCodec!,
      AVVideoWidthKey : self.width,
      AVVideoHeightKey : self.height,
      AVVideoCompressionPropertiesKey: [
       AVVideoAverageBitRateKey:  NSNumber(value: self.videoBitrate)
       ]
      ] as [String : Any]
    
    
    self.videoInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                         outputSettings: videoSettings)
    self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio,
                                         outputSettings: audioSettings)
    
    self.videoInput?.expectsMediaDataInRealTime = true
    self.audioInput?.expectsMediaDataInRealTime = true
    
    if self.assetWriter!.canAdd(self.videoInput!) {
      self.assetWriter?.add(self.videoInput!)
    }
    
    if self.assetWriter!.canAdd(self.audioInput!) {
      self.assetWriter?.add(self.audioInput!)
    }
    
    //self.deviceInput = try? AVCaptureDeviceInput(device: self.videoDevice)
    self.deviceInput = AVCaptureScreenInput(displayID: self.displayId)
    self.deviceInput!.minFrameDuration = CMTimeMake(1, Int32(self.fps))
    self.deviceInput!.capturesCursor = self.showCursor
    self.deviceInput!.capturesMouseClicks = self.highlightClicks
    
    
    self.session.startRunning()
    
    DispatchQueue.main.async {
      self.session.beginConfiguration()
      
      if self.session.canAddInput(self.deviceInput!) {
        self.session.addInput(self.deviceInput!)
      }
      
      if self.session.canAddOutput(self.videoOutput) {
        self.session.addOutput(self.videoOutput)
      }
      
      self.videoConnection = self.videoOutput.connection(with: AVMediaType.video)
      
      let audioIn = try? AVCaptureDeviceInput(device: self.audioDevice!)
      
      if self.session.canAddInput(audioIn!) {
        self.session.addInput(audioIn!)
      }
      
      if self.session.canAddOutput(self.audioOutput) {
        self.session.addOutput(self.audioOutput)
      }
      
      self.audioConnection = self.audioOutput.connection(with: AVMediaType.audio)
      
      self.session.commitConfiguration()
    }
  }
  
  func start() {
    self.startRecording()
    print("R")
  }
  
  func stop() {
    self.stopRecording()
  }
  
  func startRecording() {
    if self.assetWriter?.startWriting() != true {
      print("error: \(self.assetWriter?.error.debugDescription ?? "")")
    }
    
    self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
    self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
  }
  
  func stopRecording() {
    self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
    self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
    
    self.assetWriter?.finishWriting {
      print("Saved in folder \(self.destinationUrl)")
       exit(0)
    }
  }
  func captureOutput(_ captureOutput: AVCaptureOutput, didOutput
    sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    if !self.isRecordingSessionStarted {
      let presentationTime = CMTimeMakeWithSeconds(CACurrentMediaTime(), 240)
      self.assetWriter?.startSession(atSourceTime: presentationTime)
      self.isRecordingSessionStarted = true
    }
    
    let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
    
    if CMFormatDescriptionGetMediaType(description) == kCMMediaType_Audio {
      if self.audioInput!.isReadyForMoreMediaData {
        //print("appendSampleBuffer audio");
        self.audioInput?.append(sampleBuffer)
      }
    } else {
      if self.videoInput!.isReadyForMoreMediaData {
        //print("appendSampleBuffer video");
        if !self.videoInput!.append(sampleBuffer) {
          print("Error writing video buffer");
        }
      }
    }
  }
}

