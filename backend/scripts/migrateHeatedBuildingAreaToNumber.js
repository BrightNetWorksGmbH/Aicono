require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

/**
 * Migration script to convert heated_building_area from Decimal128 to Number
 * 
 * This script identifies buildings with heated_building_area stored as Decimal128
 * and converts them to JavaScript Number type for simpler API responses.
 * 
 * Handles:
 * - Decimal128 objects (Mongoose documents)
 * - Extended JSON format: {"$numberDecimal": "2000"}
 * - Already converted numbers (skips)
 * - Null/undefined values (skips)
 * 
 * Usage:
 *   node backend/scripts/migrateHeatedBuildingAreaToNumber.js [--dry-run]
 * 
 * Options:
 *   --dry-run: Show what would be migrated without actually migrating
 */

const DRY_RUN = process.argv.includes('--dry-run');

/**
 * Check if a value needs conversion from Decimal128 to Number
 * @param {*} value - The value to check
 * @returns {boolean} True if conversion is needed
 */
function needsConversion(value) {
  if (value === null || value === undefined) {
    return false;
  }
  
  // Already a number - no conversion needed
  if (typeof value === 'number') {
    return false;
  }
  
  // Decimal128 object (has toString method and is not a string)
  if (value && typeof value.toString === 'function' && typeof value !== 'string') {
    // Check if it's a Decimal128 by trying to convert
    try {
      const num = parseFloat(value.toString());
      return !isNaN(num) && value.toString() !== num.toString();
    } catch (e) {
      return false;
    }
  }
  
  // Extended JSON format: {"$numberDecimal": "2000"}
  if (value && typeof value === 'object' && value.$numberDecimal) {
    return true;
  }
  
  return false;
}

/**
 * Convert a Decimal128 value to Number
 * @param {*} value - The value to convert
 * @returns {number|null} Converted number or null if conversion fails
 */
function convertToNumber(value) {
  if (value === null || value === undefined) {
    return null;
  }
  
  // Already a number
  if (typeof value === 'number') {
    return value;
  }
  
  // Extended JSON format: {"$numberDecimal": "2000"}
  if (value && typeof value === 'object' && value.$numberDecimal) {
    const num = parseFloat(value.$numberDecimal);
    return isNaN(num) ? null : num;
  }
  
  // Decimal128 object
  if (value && typeof value.toString === 'function') {
    const num = parseFloat(value.toString());
    return isNaN(num) ? null : num;
  }
  
  // Try direct conversion
  const num = parseFloat(value);
  return isNaN(num) ? null : num;
}

async function migrateHeatedBuildingArea() {
  try {
    // Connect to database
    console.log('[MIGRATION] Connecting to MongoDB...');
    await connectToDatabase();
    console.log('[MIGRATION] ✓ Connected to MongoDB\n');

    const db = mongoose.connection.db;
    const collection = db.collection('buildings');

    // Count total buildings
    const totalBuildings = await collection.countDocuments();
    console.log(`[MIGRATION] Total buildings in collection: ${totalBuildings}`);

    // Find buildings with heated_building_area field
    const buildingsWithField = await collection.countDocuments({
      heated_building_area: { $exists: true, $ne: null }
    });
    console.log(`[MIGRATION] Buildings with heated_building_area field: ${buildingsWithField}\n`);

    if (buildingsWithField === 0) {
      console.log('[MIGRATION] ✓ No buildings with heated_building_area found. Nothing to migrate.');
      return;
    }

    // Fetch all buildings with heated_building_area to check which need conversion
    console.log('[MIGRATION] Analyzing buildings for conversion...');
    const buildings = await collection.find({
      heated_building_area: { $exists: true, $ne: null }
    }).toArray();

    const buildingsToMigrate = [];
    const alreadyNumbers = [];
    const invalidValues = [];

    for (const building of buildings) {
      const value = building.heated_building_area;
      
      if (needsConversion(value)) {
        const converted = convertToNumber(value);
        if (converted !== null) {
          buildingsToMigrate.push({
            _id: building._id,
            originalValue: value,
            convertedValue: converted,
            buildingName: building.name || 'Unknown'
          });
        } else {
          invalidValues.push({
            _id: building._id,
            value: value,
            buildingName: building.name || 'Unknown'
          });
        }
      } else if (typeof value === 'number') {
        alreadyNumbers.push({
          _id: building._id,
          buildingName: building.name || 'Unknown'
        });
      }
    }

    console.log(`[MIGRATION] Analysis complete:\n`);
    console.log(`  - Buildings needing conversion: ${buildingsToMigrate.length}`);
    console.log(`  - Buildings already numbers: ${alreadyNumbers.length}`);
    if (invalidValues.length > 0) {
      console.log(`  - Buildings with invalid values: ${invalidValues.length}`);
    }

    if (buildingsToMigrate.length === 0) {
      console.log('\n[MIGRATION] ✓ No buildings need conversion!');
      if (invalidValues.length > 0) {
        console.log('\n[MIGRATION] ⚠️  Warning: Some buildings have invalid heated_building_area values:');
        invalidValues.slice(0, 5).forEach((b, idx) => {
          console.log(`  ${idx + 1}. Building "${b.buildingName}" (${b._id}): ${JSON.stringify(b.value)}`);
        });
        if (invalidValues.length > 5) {
          console.log(`  ... and ${invalidValues.length - 5} more`);
        }
      }
      return;
    }

    // Show sample conversions
    console.log('\n[MIGRATION] Sample conversions:');
    buildingsToMigrate.slice(0, 5).forEach((b, idx) => {
      const originalStr = typeof b.originalValue === 'object' && b.originalValue.$numberDecimal
        ? `{"$numberDecimal": "${b.originalValue.$numberDecimal}"}`
        : b.originalValue?.toString() || JSON.stringify(b.originalValue);
      console.log(`  ${idx + 1}. "${b.buildingName}": ${originalStr} → ${b.convertedValue}`);
    });
    if (buildingsToMigrate.length > 5) {
      console.log(`  ... and ${buildingsToMigrate.length - 5} more`);
    }

    if (DRY_RUN) {
      console.log('\n[MIGRATION] 🔍 DRY RUN MODE - No data will be modified');
      console.log(`[MIGRATION] Would convert ${buildingsToMigrate.length} buildings`);
      return;
    }

    // Perform migration
    console.log('\n[MIGRATION] Starting migration...');
    let updated = 0;
    let errors = 0;
    const errorDetails = [];

    for (const building of buildingsToMigrate) {
      try {
        const result = await collection.updateOne(
          { _id: building._id },
          { $set: { heated_building_area: building.convertedValue } }
        );

        if (result.modifiedCount > 0) {
          updated++;
        } else if (result.matchedCount === 0) {
          errors++;
          errorDetails.push({
            buildingId: building._id,
            buildingName: building.buildingName,
            error: 'Building not found'
          });
        }
      } catch (error) {
        errors++;
        errorDetails.push({
          buildingId: building._id,
          buildingName: building.buildingName,
          error: error.message
        });
        
        if (errors <= 5) {
          console.error(`  ⚠️  Error updating building "${building.buildingName}" (${building._id}):`, error.message);
        }
      }

      // Progress indicator
      if ((updated + errors) % 10 === 0) {
        console.log(`  Progress: ${updated + errors}/${buildingsToMigrate.length} processed...`);
      }
    }

    console.log(`\n[MIGRATION] Migration complete:`);
    console.log(`  ✅ Updated: ${updated} buildings`);
    if (errors > 0) {
      console.log(`  ⚠️  Errors: ${errors} buildings`);
      if (errorDetails.length > 0 && errorDetails.length <= 10) {
        console.log('\n[MIGRATION] Error details:');
        errorDetails.forEach((detail, idx) => {
          console.log(`  ${idx + 1}. "${detail.buildingName}" (${detail.buildingId}): ${detail.error}`);
        });
      }
    }

    // Verification
    console.log('\n[MIGRATION] Verifying migration...');
    const remainingBuildings = await collection.find({
      heated_building_area: { $exists: true, $ne: null }
    }).toArray();

    let stillDecimal128 = 0;
    let nowNumbers = 0;
    let stillInvalid = 0;

    for (const building of remainingBuildings) {
      const value = building.heated_building_area;
      if (needsConversion(value)) {
        stillDecimal128++;
      } else if (typeof value === 'number') {
        nowNumbers++;
      } else {
        stillInvalid++;
      }
    }

    console.log(`[MIGRATION] Verification results:`);
    console.log(`  - Buildings with Number type: ${nowNumbers}`);
    if (stillDecimal128 > 0) {
      console.log(`  ⚠️  Buildings still with Decimal128: ${stillDecimal128}`);
    }
    if (stillInvalid > 0) {
      console.log(`  ⚠️  Buildings with invalid values: ${stillInvalid}`);
    }

    // Summary
    console.log('\n========================================');
    console.log('[MIGRATION] ✅ Migration Summary');
    console.log(`  Total buildings processed: ${buildingsToMigrate.length}`);
    console.log(`  Successfully updated: ${updated}`);
    console.log(`  Errors: ${errors}`);
    console.log(`  Verification - Number type: ${nowNumbers}`);
    if (stillDecimal128 > 0 || stillInvalid > 0) {
      console.log(`  ⚠️  Warnings: ${stillDecimal128} still Decimal128, ${stillInvalid} invalid`);
    }
    console.log('========================================\n');

  } catch (error) {
    console.error('[MIGRATION] ❌ Migration failed:', error.message);
    console.error('[MIGRATION] Stack:', error.stack);
    throw error;
  } finally {
    await mongoose.connection.close();
    console.log('[MIGRATION] Database connection closed');
  }
}

// Run migration if called directly
if (require.main === module) {
  migrateHeatedBuildingArea()
    .then(() => {
      console.log('[MIGRATION] ✅ Migration script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('[MIGRATION] ❌ Migration script failed:', error);
      process.exit(1);
    });
}

module.exports = { migrateHeatedBuildingArea };
