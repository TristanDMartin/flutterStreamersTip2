/**
 * Client-side video transcoding for StreamersTip website uploads.
 * Uses FFmpeg.wasm - zero server transcoding cost.
 *
 * Usage (React/Next.js):
 *   import { transcodeAndUploadVideo } from './transcodeAndUpload';
 *   const result = await transcodeAndUploadVideo(file, userId, videoId, firebaseConfig, onProgress);
 */

import { FFmpeg } from '@ffmpeg/ffmpeg';
import { fetchFile } from '@ffmpeg/util';

const FFMPEG_CORE_URL = 'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.js';
const FFMPEG_WASM_URL = 'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.wasm';

/**
 * Transcode video to 720p (TikTok spec) in browser, then upload.
 * @param {File} videoFile - Original video file
 * @param {string} userId - Firebase Auth UID
 * @param {string} videoId - Video document ID
 * @param {Object} firebaseApp - Initialized Firebase app (for Storage + Firestore)
 * @param {Function} onProgress - (percent: number, stage: string) => void
 * @returns {Promise<{success: boolean, mp4_720_url?: string, error?: string}>}
 */
export async function transcodeAndUploadVideo(videoFile, userId, videoId, firebaseApp, onProgress) {
  const { getStorage, ref, uploadBytes, getDownloadURL } = await import('firebase/storage');

  const report = (p, stage) => {
    if (typeof onProgress === 'function') onProgress(p, stage);
  };

  try {
    report(0, 'loading');
    const ffmpeg = new FFmpeg();
    ffmpeg.on('log', ({ message }) => console.log('[FFmpeg]', message));
    ffmpeg.on('progress', ({ progress }) => report(Math.min(95, progress * 50), 'transcoding'));

    await ffmpeg.load({
      coreURL: FFMPEG_CORE_URL,
      wasmURL: FFMPEG_WASM_URL,
    });

    report(5, 'transcoding');
    await ffmpeg.writeFile('input.mp4', await fetchFile(videoFile));

    const args = [
      '-i', 'input.mp4',
      '-c:v', 'libx264',
      '-c:a', 'aac',
      '-vf', 'scale=720:-2',
      '-r', '30',
      '-g', '30',
      '-movflags', '+faststart',
      '-pix_fmt', 'yuv420p',
      '-profile:v', 'high',
      '-level', '4.2',
      '-crf', '23',
      '-preset', 'fast',
      'output_720p.mp4',
    ];
    await ffmpeg.exec(args);

    const data = await ffmpeg.readFile('output_720p.mp4');
    const blob = new Blob([data], { type: 'video/mp4' });
    const transcodedFile = new File([blob], `${videoId}.mp4`, { type: 'video/mp4' });

    await ffmpeg.deleteFile('input.mp4');
    await ffmpeg.deleteFile('output_720p.mp4');

    report(55, 'uploading');
    const storage = getStorage(firebaseApp);
    const path = `videos/${userId}/${videoId}.mp4`;
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, transcodedFile, { contentType: 'video/mp4' });
    const downloadUrl = await getDownloadURL(storageRef);

    report(100, 'done');
    return { success: true, mp4_720_url: downloadUrl };
  } catch (err) {
    console.error('transcodeAndUpload error:', err);
    return { success: false, error: err?.message || String(err) };
  }
}
