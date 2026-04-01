/**
 * Lightweight format check - no transcoding.
 * If H.264/AAC and <=1080p, use original. Otherwise reject.
 * (App records 1080p; website should use client-side transcode to 720p.)
 */
const ffmpeg = require('fluent-ffmpeg');
const ffmpegStatic = require('ffmpeg-static');
const ffprobeStatic = require('ffprobe-static');

let ffprobePathInitialized = false;

function ensureFfprobePath() {
  if (ffprobePathInitialized) return;
  ffmpeg.setFfmpegPath(ffmpegStatic);
  ffmpeg.setFfprobePath(ffprobeStatic.path);
  ffprobePathInitialized = true;
}

/**
 * Check if video is mobile-playable: H.264/AAC, height <= 1080.
 * @param {string} filePath - Path to video file
 * @returns {Promise<{ok: boolean, reason?: string, metadata?: object}>}
 */
function checkFormat(filePath) {
  ensureFfprobePath();
  return new Promise((resolve) => {
    ffmpeg.ffprobe(filePath, (err, metadata) => {
      if (err) {
        resolve({ok: false, reason: 'Format check failed: ' + err.message});
        return;
      }
      const videoStream = metadata.streams.find((s) => s.codec_type === 'video');
      const audioStream = metadata.streams.find((s) => s.codec_type === 'audio');
      if (!videoStream) {
        resolve({ok: false, reason: 'No video stream'});
        return;
      }
      const codec = (videoStream.codec_name || '').toLowerCase();
      const height = videoStream.height || 0;
      const audioCodec = audioStream ? (audioStream.codec_name || '').toLowerCase() : '';
      const hasAac = audioCodec === 'aac' || !audioStream;
      const isH264 = codec === 'h264' || codec === 'avc';
      if (!isH264) {
        resolve({ok: false, reason: `Video must be H.264, got ${codec}`});
        return;
      }
      if (!hasAac && audioStream) {
        resolve({ok: false, reason: `Audio must be AAC, got ${audioCodec}`});
        return;
      }
      if (height > 1080) {
        resolve({
          ok: false,
          reason: `Height must be ≤1080p, got ${height}p. Use client-side transcoding.`,
        });
        return;
      }
      resolve({ok: true, metadata: {height, codec, audioCodec}});
    });
  });
}

module.exports = {checkFormat};
