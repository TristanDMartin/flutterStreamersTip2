// Complete function code for Firebase Console deployment
// Copy this entire file and paste into Firebase Console function editor

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {Storage} = require('@google-cloud/storage');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
const fs = require('fs');
const path = require('path');
const os = require('os');

admin.initializeApp();
ffmpeg.setFfmpegPath(ffmpegPath);

const storage = new Storage();
const db = admin.firestore();

exports.transcodeVideo = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB',
  })
  .storage.object().onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;
    const bucketName = object.bucket;

    if (!contentType || !contentType.startsWith('video/')) {
      console.log('Not a video file, skipping:', filePath);
      return null;
    }

    const pathParts = filePath.split('/');
    if (pathParts.length !== 3 || pathParts[0] !== 'videos') {
      console.log('Not in videos/{userId}/{videoId}.mp4 format, skipping:', filePath);
      return null;
    }

    const userId = pathParts[1];
    const fileName = pathParts[2];
    const videoId = fileName.replace('.mp4', '');
    
    console.log(`🎬 Processing video: ${videoId} for user: ${userId}`);

    const bucket = storage.bucket(bucketName);
    const file = bucket.file(filePath);
    
    const tempDir = os.tmpdir();
    const tempFilePath = path.join(tempDir, `${videoId}_original.mp4`);
    const temp720Path = path.join(tempDir, `${videoId}_720p.mp4`);
    const temp480Path = path.join(tempDir, `${videoId}_480p.mp4`);

    try {
      await db.collection('videos').doc(videoId).set({
        transcodingStatus: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log('📥 Downloading original video...');
      await file.download({destination: tempFilePath});
      const stats = fs.statSync(tempFilePath);
      console.log(`📦 Downloaded ${(stats.size / 1024 / 1024).toFixed(2)} MB`);

      console.log('🎞️ Generating 720p variant...');
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .videoCodec('libx264')
          .audioCodec('aac')
          .size('720x?')
          .outputOptions([
            '-preset fast',
            '-crf 23',
            '-movflags +faststart',
            '-pix_fmt yuv420p',
          ])
          .on('end', () => {
            console.log('✅ 720p generated');
            resolve();
          })
          .on('error', (err) => {
            console.error('❌ 720p error:', err);
            reject(err);
          })
          .save(temp720Path);
      });
      const stats720 = fs.statSync(temp720Path);
      console.log(`📦 720p: ${(stats720.size / 1024 / 1024).toFixed(2)} MB`);

      console.log('🎞️ Generating 480p variant...');
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .videoCodec('libx264')
          .audioCodec('aac')
          .size('480x?')
          .outputOptions([
            '-preset fast',
            '-crf 23',
            '-movflags +faststart',
            '-pix_fmt yuv420p',
          ])
          .on('end', () => {
            console.log('✅ 480p generated');
            resolve();
          })
          .on('error', (err) => {
            console.error('❌ 480p error:', err);
            reject(err);
          })
          .save(temp480Path);
      });
      const stats480 = fs.statSync(temp480Path);
      console.log(`📦 480p: ${(stats480.size / 1024 / 1024).toFixed(2)} MB`);

      console.log('📤 Uploading variants...');
      const [url720, url480, url1080] = await Promise.all([
        (async () => {
          const destPath = `videos/${userId}/${videoId}_720p.mp4`;
          await bucket.upload(temp720Path, {
            destination: destPath,
            metadata: {contentType: 'video/mp4'},
          });
          return `https://storage.googleapis.com/${bucketName}/${destPath}`;
        })(),
        (async () => {
          const destPath = `videos/${userId}/${videoId}_480p.mp4`;
          await bucket.upload(temp480Path, {
            destination: destPath,
            metadata: {contentType: 'video/mp4'},
          });
          return `https://storage.googleapis.com/${bucketName}/${destPath}`;
        })(),
        `https://storage.googleapis.com/${bucketName}/${filePath}`,
      ]);

      console.log('💾 Updating Firestore...');
      await db.collection('videos').doc(videoId).set({
        mp4_1080_url: url1080,
        mp4_720_url: url720,
        mp4_480_url: url480,
        videoUrl: url720,
        videoURL: url720,
        transcodingStatus: 'completed',
        transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log(`✅ Successfully transcoded video ${videoId}`);

      [tempFilePath, temp720Path, temp480Path].forEach(f => {
        if (fs.existsSync(f)) fs.unlinkSync(f);
      });

      return null;
    } catch (error) {
      console.error(`❌ Error transcoding video ${videoId}:`, error);
      await db.collection('videos').doc(videoId).set({
        transcodingStatus: 'failed',
        transcodingError: error.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      [tempFilePath, temp720Path, temp480Path].forEach(f => {
        if (fs.existsSync(f)) fs.unlinkSync(f);
      });

      throw error;
    }
  });

