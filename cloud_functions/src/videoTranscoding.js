const ffmpeg = require('fluent-ffmpeg');
const ffmpegStatic = require('ffmpeg-static');
const fs = require('fs');

let ffmpegPathInitialized = false;

/**
 * Initialize FFmpeg path (lazy initialization)
 * This avoids module load failures if FFmpeg isn't available
 */
function initializeFfmpegPath() {
  if (ffmpegPathInitialized) return;
  
  try {
    // Use ffmpeg-static which is more reliable in Cloud Functions
    const ffmpegPath = ffmpegStatic;
    if (!ffmpegPath) {
      throw new Error('ffmpeg-static path is undefined');
    }
    ffmpeg.setFfmpegPath(ffmpegPath);
    ffmpegPathInitialized = true;
    console.log('✅ FFmpeg path initialized:', ffmpegPath);
  } catch (error) {
    const errorMessage = error?.message || error?.toString() || String(error) || 'Unknown error';
    console.error('⚠️ Failed to initialize FFmpeg path:', errorMessage);
    console.error('⚠️ Error details:', error);
    throw new Error('FFmpeg not available: ' + errorMessage);
  }
}

/**
 * Transcode video to target resolution
 */
function transcodeVideo(inputPath, outputPath, resolution) {
  // Initialize FFmpeg path only when actually needed
  initializeFfmpegPath();
  
  return new Promise((resolve, reject) => {
    console.log(`🎬 Starting transcoding: ${resolution}p`);
    
    const command = ffmpeg(inputPath)
      .videoCodec('libx264')
      .audioCodec('aac')
      .size(`${resolution}x?`) // Maintain aspect ratio
      .outputOptions([
        '-preset fast',
        '-crf 23',
        '-r 30', // TikTok standard
        '-g 30', // Keyframe every 1s (TikTok scrubbing)
        '-movflags +faststart',
        '-pix_fmt yuv420p',
        '-profile:v high', // H.264 High Profile (TikTok)
        '-level 4.2', // H.264 level 4.2 (TikTok)
        '-maxrate 2M',
        '-bufsize 4M',
      ])
      .on('start', (commandLine) => {
        console.log(`🎬 FFmpeg command: ${commandLine}`);
      })
      .on('progress', (progress) => {
        if (progress.percent) {
          console.log(`⏳ Transcoding ${resolution}p: ${progress.percent.toFixed(1)}%`);
        }
      })
      .on('end', () => {
        console.log(`✅ Transcoding completed: ${resolution}p`);
        resolve();
      })
      .on('error', (err) => {
        console.error(`❌ Transcoding error (${resolution}p):`, err.message);
        reject(err);
      });

    command.save(outputPath);
  });
}

/**
 * Upload transcoded variant to Storage
 */
async function uploadVariant(bucket, userId, videoId, filePath, resolution) {
  const destinationPath = `videos/${userId}/${videoId}_${resolution}.mp4`;
  const destinationFile = bucket.file(destinationPath);
  
  console.log(`📤 Uploading ${resolution} variant to ${destinationPath}...`);
  
  await bucket.upload(filePath, {
    destination: destinationPath,
    metadata: {
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000', // Cache for 1 year
      metadata: {
        resolution: resolution,
        videoId: videoId,
        transcodedAt: new Date().toISOString(),
      },
    },
  });

  // Make file publicly accessible
  try {
    await destinationFile.makePublic();
    console.log(`✅ Made ${resolution} variant public`);
  } catch (error) {
    console.warn(`⚠️ Could not make ${resolution} variant public (may already be public):`, error.message);
  }

  // Construct public URL
  const url = `https://storage.googleapis.com/${bucket.name}/${destinationPath}`;
  
  console.log(`✅ Uploaded ${resolution} variant: ${url}`);
  return url;
}

/**
 * Get public URL for original file
 */
async function getPublicUrl(file) {
  try {
    // Try to make file public first (if bucket allows)
    await file.makePublic().catch(() => {
      // Ignore if already public or if we don't have permissions
    });
    
    // Construct public URL
    return `https://storage.googleapis.com/${file.bucket.name}/${file.name}`;
  } catch (error) {
    console.error('Error getting public URL:', error);
    // Fallback: use signed URL (less ideal but works)
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-09-2491', // Far future date
    });
    return url;
  }
}

/**
 * Cleanup temporary files
 */
function cleanupFiles(filePaths) {
  filePaths.forEach((filePath) => {
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        console.log(`🧹 Cleaned up: ${filePath}`);
      }
    } catch (error) {
      console.error(`⚠️ Failed to cleanup ${filePath}:`, error);
    }
  });
}

module.exports = {
  transcodeVideo,
  uploadVariant,
  getPublicUrl,
  cleanupFiles,
};
