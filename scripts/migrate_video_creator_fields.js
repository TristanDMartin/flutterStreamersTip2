/**
 * Migration script to add creatorId and creator_id fields to existing videos
 * that only have userId field
 * 
 * Run this script with:
 * node scripts/migrate_video_creator_fields.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateVideoCreatorFields() {
  console.log('🔄 Starting video creator field migration...');
  
  try {
    // Get all videos
    const videosSnapshot = await db.collection('videos').get();
    console.log(`📊 Found ${videosSnapshot.docs.length} videos to process`);
    
    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    
    // Process videos in batches
    const batch = db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 500;
    
    for (const doc of videosSnapshot.docs) {
      const data = doc.data();
      const videoId = doc.id;
      
      // Check if video already has all three fields
      const hasUserId = data.hasOwnProperty('userId');
      const hasCreatorId = data.hasOwnProperty('creatorId');
      const hasCreatorIdSnake = data.hasOwnProperty('creator_id');
      
      if (hasUserId && hasCreatorId && hasCreatorIdSnake) {
        console.log(`✅ Video ${videoId} already has all creator fields, skipping`);
        skippedCount++;
        continue;
      }
      
      // Get the userId value (could be in any of the three fields)
      const userId = data.userId || data.creatorId || data.creator_id;
      
      if (!userId) {
        console.log(`⚠️  Video ${videoId} has no valid creator ID, skipping`);
        errorCount++;
        continue;
      }
      
      // Build update data
      const updateData = {};
      const missingFields = [];
      
      if (!hasUserId) {
        updateData.userId = userId;
        missingFields.push('userId');
      }
      if (!hasCreatorId) {
        updateData.creatorId = userId;
        missingFields.push('creatorId');
      }
      if (!hasCreatorIdSnake) {
        updateData.creator_id = userId;
        missingFields.push('creator_id');
      }
      
      if (Object.keys(updateData).length > 0) {
        batch.update(doc.ref, updateData);
        batchCount++;
        console.log(`📝 Queued update for video ${videoId}: ${missingFields.join(', ')}`);
        updatedCount++;
        
        // Commit batch if it reaches the size limit
        if (batchCount >= BATCH_SIZE) {
          console.log(`💾 Committing batch of ${batchCount} updates...`);
          await batch.commit();
          batchCount = 0;
        }
      }
    }
    
    // Commit any remaining updates
    if (batchCount > 0) {
      console.log(`💾 Committing final batch of ${batchCount} updates...`);
      await batch.commit();
    }
    
    console.log('');
    console.log('✅ Migration complete!');
    console.log('📊 Statistics:');
    console.log(`   - Updated: ${updatedCount} videos`);
    console.log(`   - Skipped: ${skippedCount} videos`);
    console.log(`   - Errors: ${errorCount} videos`);
    console.log(`   - Total processed: ${videosSnapshot.docs.length} videos`);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run the migration
migrateVideoCreatorFields()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });

