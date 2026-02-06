require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

/**
 * Script to clear old aggregated data from measurements_aggregated collection
 * 
 * This script drops all aggregated data to allow re-aggregation with corrected logic.
 * Since raw data is cleaned up after aggregation, we cannot re-aggregate old data.
 * 
 * After running this:
 * 1. The aggregation scheduler will automatically recreate aggregates from new raw data
 * 2. Historical data before the fix will be lost (cannot be recovered)
 * 3. New data will be aggregated correctly going forward
 * 
 * Usage: node backend/scripts/clearOldAggregatedData.js
 * 
 * WARNING: This will delete ALL aggregated data. Make sure you understand
 * the implications before running this script.
 */

async function clearOldAggregatedData() {
    try {
        // Connect to database
        await connectToDatabase();
        console.log('✅ Connected to database');
        
        const db = mongoose.connection.db;
        const collection = db.collection('measurements_aggregated');
        
        // Check if collection exists
        const collections = await db.listCollections({ name: 'measurements_aggregated' }).toArray();
        if (collections.length === 0) {
            console.log('✅ Collection measurements_aggregated does not exist. Nothing to clear.');
            return;
        }
        
        // Count documents before deletion
        console.log('🔍 Counting aggregated documents...');
        const count = await collection.countDocuments();
        
        if (count === 0) {
            console.log('✅ No aggregated documents found. Nothing to clear.');
            return;
        }
        
        console.log(`   Found ${count} aggregated documents to delete\n`);
        
        // Show breakdown by resolution
        console.log('📊 Breakdown by resolution:');
        const breakdown = await collection.aggregate([
            {
                $group: {
                    _id: '$resolution_minutes',
                    count: { $sum: 1 }
                }
            },
            {
                $sort: { _id: 1 }
            }
        ]).toArray();
        
        breakdown.forEach(item => {
            const resolution = item._id || 0;
            const label = resolution === 0 ? 'Raw (0)' :
                         resolution === 15 ? '15-minute' :
                         resolution === 60 ? 'Hourly' :
                         resolution === 1440 ? 'Daily' :
                         resolution === 10080 ? 'Weekly' :
                         resolution === 43200 ? 'Monthly' :
                         `${resolution}-minute`;
            console.log(`   - ${label}: ${item.count} documents`);
        });
        
        console.log('\n⚠️  WARNING: This will delete ALL aggregated data.');
        console.log('⚠️  Since raw data is cleaned up after aggregation, this data cannot be recovered.');
        console.log('⚠️  The system will re-aggregate from new raw data going forward.\n');
        
        // Delete all documents
        console.log('🗑️  Deleting all aggregated documents...');
        const result = await collection.deleteMany({});
        
        console.log(`✅ Deleted ${result.deletedCount} documents`);
        
        // Verify deletion
        const remainingCount = await collection.countDocuments();
        if (remainingCount === 0) {
            console.log('✅ Verification: All aggregated data has been cleared.');
            console.log('\n📝 Next steps:');
            console.log('   1. The aggregation scheduler will automatically recreate aggregates from new raw data');
            console.log('   2. Historical data before this fix will be lost');
            console.log('   3. New data will be aggregated correctly with the fixed logic');
        } else {
            console.warn(`⚠️  Warning: ${remainingCount} documents still remain. Please check manually.`);
        }
        
    } catch (error) {
        console.error('❌ Error clearing aggregated data:', error.message);
        console.error('Stack:', error.stack);
        process.exit(1);
    } finally {
        await mongoose.connection.close();
        console.log('\n✅ Database connection closed');
    }
}

// Run script
if (require.main === module) {
    clearOldAggregatedData()
        .then(() => {
            console.log('\n✅ Script completed successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n❌ Script failed:', error.message);
            process.exit(1);
        });
}

module.exports = { clearOldAggregatedData };
