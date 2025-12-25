const mongoose = require('mongoose');

// Connection strings
const SOURCE_URI = 'source_uri';
const TARGET_URI = 'target_uri';

// Helper function to wait for mongoose connection
function waitForConnection(connection) {
  return new Promise((resolve, reject) => {
    if (connection.readyState === 1) {
      resolve(connection);
      return;
    }
    
    connection.on('connected', () => resolve(connection));
    connection.on('error', (err) => reject(err));
    
    // Timeout after 30 seconds
    setTimeout(() => {
      if (connection.readyState !== 1) {
        reject(new Error('Connection timeout'));
      }
    }, 30000);
  });
}

async function migrateDatabase() {
  let sourceConnection = null;
  let targetConnection = null;

  try {
    console.log('🔄 Starting database migration from "admin" to "aicono"...\n');

    // Connect to source database (admin)
    console.log('📡 Connecting to source database (admin)...');
    sourceConnection = mongoose.createConnection(SOURCE_URI, {
      serverSelectionTimeoutMS: 30000,
      socketTimeoutMS: 45000,
    });
    await waitForConnection(sourceConnection);
    console.log('✅ Connected to source database\n');

    // Connect to target database (aicono)
    console.log('📡 Connecting to target database (aicono)...');
    targetConnection = mongoose.createConnection(TARGET_URI, {
      serverSelectionTimeoutMS: 30000,
      socketTimeoutMS: 45000,
    });
    await waitForConnection(targetConnection);
    console.log('✅ Connected to target database\n');

    // Get database references
    const sourceDb = sourceConnection.db;
    const targetDb = targetConnection.db;

    const collections = await sourceDb.listCollections().toArray();
    console.log(`📋 Found ${collections.length} collections to migrate:\n`);

    const migrationResults = [];

    // Migrate each collection
    for (const collectionInfo of collections) {
      const collectionName = collectionInfo.name;
      
      // Skip system collections
      if (collectionName.startsWith('system.')) {
        console.log(`⏭️  Skipping system collection: ${collectionName}`);
        continue;
      }

      console.log(`\n📦 Migrating collection: ${collectionName}...`);

      try {
        const sourceCollection = sourceDb.collection(collectionName);
        const targetCollection = targetDb.collection(collectionName);

        // Get collection options (for time-series collections)
        const collectionOptions = collectionInfo.options || {};

        // Check if it's a time-series collection
        const isTimeSeries = collectionOptions.timeseries !== undefined;

        // Create collection in target database with same options
        if (isTimeSeries) {
          console.log(`   ⚠️  Time-series collection detected: ${collectionName}`);
          try {
            await targetDb.createCollection(collectionName, collectionOptions);
            console.log(`   ✅ Created time-series collection: ${collectionName}`);
          } catch (error) {
            if (error.code === 48) {
              // Collection already exists
              console.log(`   ℹ️  Collection already exists: ${collectionName}`);
            } else {
              throw error;
            }
          }
        }

        // Count documents in source
        const sourceCount = await sourceCollection.countDocuments();
        console.log(`   📊 Source documents: ${sourceCount}`);

        if (sourceCount === 0) {
          console.log(`   ⏭️  No documents to migrate`);
          migrationResults.push({
            collection: collectionName,
            status: 'skipped',
            count: 0,
          });
          continue;
        }

        // Verify we can actually read from source
        const testDoc = await sourceCollection.findOne({});
        if (!testDoc) {
          console.log(`   ⚠️  Warning: Collection has count ${sourceCount} but couldn't read a document`);
        } else {
          console.log(`   ✅ Verified: Can read documents from source (sample _id: ${testDoc._id})`);
        }

        // Copy documents in batches
        const batchSize = 1000;
        let totalCopied = 0;
        let skip = 0;
        let batchNumber = 0;

        while (true) {
          batchNumber++;
          const batch = await sourceCollection
            .find({})
            .skip(skip)
            .limit(batchSize)
            .toArray();

          if (batch.length === 0) {
            console.log(`   ℹ️  No more documents to copy (batch ${batchNumber})`);
            break;
          }

          console.log(`   📦 Batch ${batchNumber}: Retrieved ${batch.length} documents from source`);

          // Insert batch into target collection
            try {
            const insertResult = await targetCollection.insertMany(batch, { ordered: false });
            const insertedCount = insertResult.insertedCount || batch.length;
            totalCopied += insertedCount;
            console.log(`   📝 Copied ${totalCopied}/${sourceCount} documents (inserted: ${insertedCount})...`);
            } catch (error) {
            console.error(`   ⚠️  Batch insert error:`, error.message);
              // Handle duplicate key errors (if re-running migration)
            if (error.code === 11000 || error.writeErrors) {
              console.log(`   🔄 Attempting to upsert documents individually...`);
                // Try to upsert instead
              let upserted = 0;
                for (const doc of batch) {
                  try {
                  const result = await targetCollection.replaceOne(
                      { _id: doc._id },
                      doc,
                      { upsert: true }
                    );
                  if (result.upsertedCount > 0 || result.modifiedCount > 0) {
                    upserted++;
                    totalCopied++;
                  }
                  } catch (err) {
                    console.error(`   ⚠️  Error upserting document ${doc._id}:`, err.message);
                  }
                }
              console.log(`   ✅ Upserted ${upserted} documents from this batch`);
              } else {
              console.error(`   ❌ Fatal error inserting batch:`, error);
                throw error;
            }
          }

          skip += batchSize;
          if (batch.length < batchSize) break;
        }

        // Verify migration
        const targetCount = await targetCollection.countDocuments();
        console.log(`   ✅ Migrated: ${totalCopied} documents`);
        console.log(`   ✅ Target documents: ${targetCount}`);

        if (targetCount === sourceCount) {
          console.log(`   ✅ Verification: Counts match!`);
        } else {
          console.log(`   ⚠️  Warning: Count mismatch (source: ${sourceCount}, target: ${targetCount})`);
        }

        migrationResults.push({
          collection: collectionName,
          status: 'success',
          sourceCount,
          targetCount,
        });

      } catch (error) {
        console.error(`   ❌ Error migrating ${collectionName}:`, error.message);
        migrationResults.push({
          collection: collectionName,
          status: 'error',
          error: error.message,
        });
      }
    }

    // Print summary
    console.log('\n\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60) + '\n');

    const successful = migrationResults.filter(r => r.status === 'success');
    const failed = migrationResults.filter(r => r.status === 'error');
    const skipped = migrationResults.filter(r => r.status === 'skipped');

    console.log(`✅ Successful: ${successful.length}`);
    successful.forEach(r => {
      console.log(`   - ${r.collection}: ${r.targetCount} documents`);
    });

    if (skipped.length > 0) {
      console.log(`\n⏭️  Skipped: ${skipped.length}`);
      skipped.forEach(r => {
        console.log(`   - ${r.collection}: ${r.count} documents`);
      });
    }

    if (failed.length > 0) {
      console.log(`\n❌ Failed: ${failed.length}`);
      failed.forEach(r => {
        console.log(`   - ${r.collection}: ${r.error}`);
      });
    }

    console.log('\n' + '='.repeat(60));
    console.log('✨ Migration completed!');
    console.log('='.repeat(60) + '\n');

  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('Error details:', error);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  } finally {
    // Close connections
    if (sourceConnection) {
      await sourceConnection.close();
      console.log('🔌 Closed source database connection');
    }
    if (targetConnection) {
      await targetConnection.close();
      console.log('🔌 Closed target database connection');
    }
    process.exit(0);
  }
}

// Run migration
migrateDatabase().catch(console.error);