# Aicono Energy Management System - Backend

A Node.js/Express backend API for the Aicono Energy Management System (EMS).

## Project Structure

```
backend/
├── config/          # Configuration files
├── controllers/     # Route controllers
├── db/             # Database connection
│   └── connection.js
├── middleware/     # Express middleware
│   └── errorHandler.js
├── models/         # Mongoose models (19 models)
│   ├── BryteSwitchSettings.js
│   ├── User.js
│   ├── Role.js
│   ├── UserRole.js
│   ├── Invitation.js
│   ├── Site.js
│   ├── Building.js
│   ├── Floor.js
│   ├── Room.js
│   ├── Sensor.js
│   ├── MeasurementData.js
│   ├── Tariff.js
│   ├── CostData.js
│   ├── AlarmRule.js
│   ├── AlarmLog.js
│   ├── Comment.js
│   ├── RenovationProject.js
│   ├── Benchmark.js
│   ├── ActivityLog.js
│   └── index.js
├── routes/         # Express routes
│   └── index.js
├── services/       # Business logic services
├── utils/          # Utility functions
│   └── errors.js
├── .env            # Environment variables (create from .env.example)
├── .env.example    # Example environment variables
├── .gitignore
├── index.js        # Main application entry point
├── package.json
└── README.md
```

## Database Schema

The system uses MongoDB with 19 collections representing:

### I. User & Organization
- **BryteSwitchSettings**: Organization/tenant settings
- **User**: User accounts
- **Role**: User roles (Admin, Owner, Expert, Read-Only)
- **UserRole**: User-role assignments per organization
- **Invitation**: User invitations

### II. Master Data (M1 & Loxone Mapping)
- **Site**: Physical sites
- **Building**: Buildings within sites
- **Floor**: Floors within buildings
- **Room**: Rooms within floors
- **Sensor**: Sensors within rooms

### III. Core Analytical Data
- **MeasurementData**: Sensor measurement readings
- **Tariff**: Energy tariffs per building
- **CostData**: Cost calculations
- **AlarmRule**: Alarm rule definitions
- **AlarmLog**: Alarm event logs
- **Benchmark**: Energy benchmarks by building type

### IV. Operational & Collaboration
- **RenovationProject**: Building renovation projects
- **Comment**: Comments on buildings, sensors, or alarms
- **ActivityLog**: System activity audit log

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment variables:**
   - Copy `.env.example` to `.env`
   - Update `MONGODB_URI` with your MongoDB connection string
   - Set `JWT_SECRET` for authentication tokens

3. **Run the server:**
   ```bash
   # Development mode (with nodemon)
   npm run dev

   # Production mode
   npm start
   ```

## Environment Variables

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment (development/production)
- `MONGODB_URI`: MongoDB connection string
- `JWT_SECRET`: Secret key for JWT tokens

## API Endpoints

### Health Check
- `GET /` - API information
- `GET /health` - Health check endpoint

## Dependencies

- **express**: Web framework
- **mongoose**: MongoDB ODM
- **dotenv**: Environment variable management
- **cors**: Cross-origin resource sharing
- **express-validator**: Request validation
- **jsonwebtoken**: JWT authentication
- **bcryptjs**: Password hashing

## Development Dependencies

- **nodemon**: Auto-restart server during development

## Notes

- All models include timestamps (createdAt, updatedAt)
- Indexes are created for efficient querying
- Decimal128 is used for precise decimal values (areas, costs, measurements)
- Polymorphic relationships are used for Comments (can link to Building, Sensor, or AlarmLog)

