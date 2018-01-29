'use strict';
const fs = require('fs');
const delay = require('delay');
const aperture = require('.');

async function main() {
  const recorder = aperture();
  console.log('Audio devices:', await aperture.audioDevices());
  console.log('Display list:', await aperture.displayDevices());
  console.log('Preparing to record for 5 seconds');
  await recorder.startRecording({
    fps: 30,
    audioDeviceId: "AppleHDAEngineInput:1B,0,1,0:1",
    displayId: "724042646"
  });
  console.log('Recording started');
  await delay(5000);
  const fp = await recorder.stopRecording();
  fs.renameSync(fp, 'recording.mp4');
  console.log('Video saved in the current directory');
}

main().catch(console.error);

// Run: $ node example.js
