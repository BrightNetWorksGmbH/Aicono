/**
 * MongoDB Setup Script for Loxone Connection
 * 
 * This script helps you:
 * 1. Create a Building document in MongoDB
 * 2. Get the Building ID for your .env file
 * 3. Verify collections exist
 * 
 * Usage: node setupMongoDB.js
 */

const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config();

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/aicono';

// Load models
let Building, Site;
try {
    const path = require('path');
    const modelsPath = path.join(__dirname, '../backend/models');
    const models = require(path.join(modelsPath, 'index.js'));
    Building = models.Building;
    Site = models.Site;
    console.log('[SETUP] Loaded models from backend');
} catch (error) {
    console.error('[SETUP] Could not load backend models:', error.message);
    console.log('[SETUP] Using inline model definitions...');
    
    // Inline definitions (simplified for setup)
    const siteSchema = new mongoose.Schema({
        name: String,
        address: String,
        resource_type: String,
        bryteswitch_id: { type: mongoose.Schema.Types.ObjectId, ref: 'BryteSwitchSettings' }
    }, { collection: 'sites' });
    Site = mongoose.models.Site || mongoose.model('Site', siteSchema);
    
    const buildingSchema = new mongoose.Schema({
        site_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Site' },
        name: String,
        heated_building_area: mongoose.Schema.Types.Decimal128,
        type_of_use: String,
        num_students_employees: Number,
        miniserver_ip: String,
        miniserver_serial: String,
        miniserver_auth_token: String
    }, { collection: 'buildings' });
    Building = mongoose.models.Building || mongoose.model('Building', buildingSchema);
}

async function setupMongoDB() {
    try {
        console.log('[SETUP] Connecting to MongoDB...');
        console.log(`[SETUP] URI: ${MONGODB_URI.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')}`); // Mask credentials
        
        // Connect with better error handling
        await mongoose.connect(MONGODB_URI, {
            autoIndex: false, // Disable auto-index to avoid schema conflicts
            serverSelectionTimeoutMS: 15000, // Increased timeout
            socketTimeoutMS: 45000,
            maxPoolSize: 10,
        });
        
        // Wait for connection to be ready
        await mongoose.connection.db.admin().ping();
        console.log('[SETUP] ✓ Connected to MongoDB');
        console.log(`[SETUP] Database: ${mongoose.connection.db.databaseName}`);
        
        // List existing collections
        const collections = await mongoose.connection.db.listCollections().toArray();
        console.log(`[SETUP] Existing collections: ${collections.map(c => c.name).join(', ') || 'none'}`);

        // Check if Building already exists for this Miniserver
        const miniserverSerial = process.env.LOXONE_SERIAL || '504F94D107EE';
        console.log(`[SETUP] Checking for Building with serial: ${miniserverSerial}`);
        
        // Use native MongoDB driver to avoid buffering issues
        const db = mongoose.connection.db;
        const buildingsCollection = db.collection('buildings');
        const existingBuildingDoc = await buildingsCollection.findOne({ 
            miniserver_serial: miniserverSerial 
        });
        
        let existingBuilding = null;
        if (existingBuildingDoc) {
            // Convert to Mongoose document if found
            existingBuilding = new Building(existingBuildingDoc);
            existingBuilding.isNew = false;
        }

        if (existingBuilding) {
            console.log('\n[SETUP] ✓ Building already exists!');
            console.log(`[SETUP] Building ID: ${existingBuilding._id}`);
            console.log(`[SETUP] Building Name: ${existingBuilding.name}`);
            console.log('\n[SETUP] Add this to your .env file:');
            console.log(`BUILDING_ID=${existingBuilding._id}`);
            return existingBuilding._id;
        }

        // Create a Site if none exists
        console.log('[SETUP] Checking for existing Site...');
        const sitesCollection = db.collection('sites');
        let siteDoc = await sitesCollection.findOne({});
        let site = null;
        if (siteDoc) {
            site = new Site(siteDoc);
            site.isNew = false;
        }
        if (!site) {
            console.log('[SETUP] No Site found, creating default Site...');
            
            // Check if BryteSwitchSettings exists (required for Site)
            let bryteswitchSettings = null;
            try {
                const bryteswitchCollection = db.collection('bryteswitchsettings');
                let bryteswitchDoc = await bryteswitchCollection.findOne({});
                
                if (!bryteswitchDoc) {
                    console.log('[SETUP] Creating default BryteSwitchSettings...');
                    const bryteswitchData = {
                        organization_name: 'Default Organization',
                        sub_domain: 'default',
                        is_setup_complete: false,
                        createdAt: new Date(),
                        updatedAt: new Date()
                    };
                    const result = await bryteswitchCollection.insertOne(bryteswitchData);
                    bryteswitchDoc = await bryteswitchCollection.findOne({ _id: result.insertedId });
                    console.log(`[SETUP] ✓ Created BryteSwitchSettings: ${bryteswitchDoc._id}`);
                } else {
                    console.log(`[SETUP] Using existing BryteSwitchSettings: ${bryteswitchDoc._id}`);
                }
                
                bryteswitchSettings = bryteswitchDoc;
            } catch (error) {
                console.error('[SETUP] Error creating BryteSwitchSettings:', error.message);
                bryteswitchSettings = null;
            }
            
            if (bryteswitchSettings) {
                const siteData = {
                    name: 'Default Site',
                    address: '',
                    resource_type: 'Building',
                    bryteswitch_id: bryteswitchSettings._id,
                    createdAt: new Date(),
                    updatedAt: new Date()
                };
                const siteResult = await sitesCollection.insertOne(siteData);
                siteDoc = await sitesCollection.findOne({ _id: siteResult.insertedId });
                site = new Site(siteDoc);
                site.isNew = false;
                console.log(`[SETUP] ✓ Created Site: ${site._id}`);
            } else {
                throw new Error('Cannot create Site without BryteSwitchSettings. Please create a Site manually via your backend API.');
            }
        } else {
            console.log(`[SETUP] Using existing Site: ${site.name} (${site._id})`);
        }

        // Create Building
        console.log('\n[SETUP] Creating Building document...');
        const buildingData = {
            site_id: site._id,
            name: process.env.BUILDING_NAME || 'ECO-Detect Building',
            miniserver_ip: process.env.LOXONE_IP || '192.168.178.201',
            miniserver_serial: miniserverSerial,
            miniserver_auth_token: '', // Will be updated when token is received
            type_of_use: process.env.BUILDING_TYPE_OF_USE || 'Commercial',
            createdAt: new Date(),
            updatedAt: new Date()
        };

        // Use native insertOne to avoid buffering
        const buildingResult = await buildingsCollection.insertOne(buildingData);
        const building = await buildingsCollection.findOne({ _id: buildingResult.insertedId });
        console.log('\n[SETUP] ✓ Building created successfully!');
        console.log(`[SETUP] Building ID: ${building._id}`);
        console.log(`[SETUP] Building Name: ${building.name}`);
        console.log(`[SETUP] Miniserver Serial: ${building.miniserver_serial}`);
        
        console.log('\n[SETUP] ⚠️  IMPORTANT: Add this to your .env file:');
        console.log(`BUILDING_ID=${building._id}`);
        console.log('\n[SETUP] Then restart the connection to enable MongoDB storage.');

        return building._id;
    } catch (error) {
        console.error('[SETUP] Error:', error.message);
        
        // Provide helpful error messages
        if (error.message.includes('buffering timed out') || error.message.includes('ECONNREFUSED')) {
            console.error('\n[SETUP] ⚠️  MongoDB Connection Failed!');
            console.error('[SETUP] Possible issues:');
            console.error('  1. MongoDB is not running locally');
            console.error('  2. Wrong connection string in MONGODB_URI');
            console.error('  3. Network/firewall blocking connection');
            console.error('\n[SETUP] Solutions:');
            console.error('  Option A: Start MongoDB locally:');
            console.error('    brew services start mongodb-community  # macOS');
            console.error('    sudo systemctl start mongod           # Linux');
            console.error('\n  Option B: Use DigitalOcean MongoDB:');
            console.error('    Update .env with:');
            console.error('    MONGODB_URI=mongodb+srv://doadmin:6014M7Tk3G85fOqN@db-brightspace-f64857eb.mongo.ondigitalocean.com/admin?tls=true&authSource=admin&replicaSet=db-brightspace');
        }
        
        throw error;
    } finally {
        await mongoose.disconnect();
        console.log('\n[SETUP] Disconnected from MongoDB');
    }
}

// Run setup
if (require.main === module) {
    setupMongoDB()
        .then(() => {
            console.log('\n[SETUP] Setup complete!');
            process.exit(0);
        })
        .catch(error => {
            console.error('\n[SETUP] Setup failed:', error);
            process.exit(1);
        });
}

module.exports = { setupMongoDB };

