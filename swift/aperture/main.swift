import Foundation
import AVFoundation
import CoreGraphics

var recorder: NewRecorder!
let arguments = CommandLine.arguments.dropFirst()

func quit(_: Int32) {
  recorder.stop()
  // Do not call `exit()` here as the video is not always done
  // saving at this point and will be corrupted randomly
}

struct Options: Decodable {
  let destination: URL
  let fps: Int
  let cropRect: CGRect?
  let showCursor: Bool
  let highlightClicks: Bool
  let displayId: String
  let audioDeviceId: String?
  let videoCodec: String?
  let width: Int
  let height: Int
  let audioBitrate: Int
  let videoBitrate: Int  
}

func record() throws {
  let json = arguments.first!.data(using: .utf8)!
  let options = try JSONDecoder().decode(Options.self, from: json)
  
  recorder = NewRecorder(
    destination: options.destination,
    fps: options.fps,
    cropRect: options.cropRect,
    showCursor: options.showCursor,
    highlightClicks: options.highlightClicks,
    displayId: options.displayId == "main" ? CGMainDisplayID() : CGDirectDisplayID(options.displayId)!,
    audioDevice: options.audioDeviceId != nil ? AVCaptureDevice(uniqueID: options.audioDeviceId!) : nil,
    videoCodec: options.videoCodec!,
    width: 1920,
    height: 1080,
    audioBitrate: 192000,
    videoBitrate: 5000000
  )
  recorder.setup()
  
  signal(SIGHUP, quit)
  signal(SIGINT, quit)
  signal(SIGTERM, quit)
  signal(SIGQUIT, quit)

  recorder.start()
  setbuf(__stdoutp, nil)

  RunLoop.main.run()
}

func usage() {
  print(
    """
    Usage:
      aperture <options>
      aperture list-audio-devices
      aperture list-displays
    """
  )
}

func printDisplays() throws  {
  var displayCount: UInt32 = 0;
  var result = CGGetActiveDisplayList(0, nil, &displayCount)
  if (result != CGError.success) {
    printErr("error: \(result)")
    return
  }
  let allocated = Int(displayCount)
  let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
  result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
  if (result != CGError.success) {
    printErr("error: \(result)")
    return
  }
  print("\(displayCount) displays:")
  var displays: [Dictionary<String, String>] = []
  
  for i in 0..<displayCount {
    displays.append(["id": "\(i)", "name": "\(activeDisplays[Int(i)])"])
  }
  activeDisplays.deallocate(capacity: allocated)
  printErr(try toJson(displays))
}


if arguments.first == "list-audio-devices" {
  // Uses stderr because of unrelated stuff being outputted on stdout
  printErr(try toJson(DeviceList.audio()))
  exit(0)
}

if arguments.first == "list-displays" {
  try printDisplays()

  exit(0)
}

if arguments.first != nil {
  try record()
  exit(0)
}

usage()
exit(1)
