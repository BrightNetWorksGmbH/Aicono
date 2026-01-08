# Category-Based Measurement Type Inference & Implementation Guide

## Overview

This document explains how categories (`cats`) are utilized to determine measurement types, the difference between control types and measurement types, and the frequency of real-time data storage.

---

## 1. Categories (`cats`) - Purpose and Implementation

### What are Categories?

Categories in Loxone group controls **logically** (similar to how rooms group them by location). Each category has:
- `type`: Semantic info (e.g., `lights`, `indoortemperature`, `shading`, `media`)
- `name`: Human-readable name (e.g., "Energie", "Temperatur", "Heizung")
- `color`: UI color for visualization

### How We Use Categories

**Priority-based measurement type inference:**

1. **Priority 1: Category Type** (most specific)
   - `indoortemperature` → `Temperature`
   - `lights` → `Lighting`
   - `shading` → `Shading`
   - `media` / `multimedia` → `Media`

2. **Priority 2: Category Name** (when type is "undefined")
   - "Energie" / "Energy" / "Strom" → `Energy`
   - "Temperatur" / "Temperature" → `Temperature`
   - "Wasser" / "Water" → `Water`
   - "Heizung" / "Heating" → `Heating`
   - "Klima" / "Climate" → `Climate`
   - "Beleuchtung" / "Light" → `Lighting`

3. **Priority 3: Control Type** (fallback)
   - `Meter` → `Energy`
   - `EFM` → `Energy`
   - `TemperatureController` → `Temperature`
   - etc.

### Implementation

**Storage in Sensors:**
- `loxone_category_uuid`: Reference to category UUID
- `loxone_category_name`: Category name (e.g., "Energie")
- `loxone_category_type`: Category type (e.g., "indoortemperature")

**Usage in UUID Mapping:**
- Category info is stored in `uuidToSensorMap` entries
- Used during measurement storage to infer measurement type

---

## 2. Control Types vs Measurement Types

### Control Types (Loxone-specific)

**What they are:**
- Loxone's internal classification of devices/controls
- Examples: `Meter`, `EFM`, `TemperatureController`, `WaterMeter`, `PowerMeter`, `InfoOnlyAnalog`, `AnalogInput`, `DigitalInput`

**Where they come from:**
- Defined in `LoxAPP3.json` structure file
- Each control has a `type` field

**Current implementation:**
```javascript
const measurementTypes = [
    'TemperatureController', 'EnergyMeter', 'WaterMeter', 'PowerMeter',
    'AnalogInput', 'DigitalInput', 'Meter', 'InfoOnlyAnalog', 'EFM'
];
```

### Measurement Types (Our internal classification)

**What they are:**
- Our standardized classification for storage and analysis
- Examples: `Energy`, `Temperature`, `Water`, `Power`, `Heating`, `Climate`, `Lighting`, `Media`, `Analog`, `Digital`

**Where they're used:**
- Stored in MongoDB `measurements` collection as `meta.measurementType`
- Used for filtering, aggregation, and reporting

**Mapping:**
```javascript
// Control Type → Measurement Type
'Meter' → 'Energy'
'EFM' → 'Energy'
'TemperatureController' → 'Temperature'
'WaterMeter' → 'Water'
'PowerMeter' → 'Power'
'AnalogInput' → 'Analog'
'InfoOnlyAnalog' → 'Analog'
'DigitalInput' → 'Digital'
```

### Key Differences

| Aspect | Control Type | Measurement Type |
|--------|-------------|------------------|
| **Source** | Loxone structure file | Our inference logic |
| **Purpose** | Device classification | Data classification |
| **Examples** | `Meter`, `EFM`, `TemperatureController` | `Energy`, `Temperature`, `Water` |
| **Flexibility** | Fixed by Loxone | Can be enhanced with categories |
| **Storage** | In sensor document (`controlType`) | In measurement document (`meta.measurementType`) |

---

## 3. Missing Control Types and Measurement Types

### Currently Supported Control Types

✅ **Fully Supported:**
- `Meter` → `Energy`
- `EFM` (Energy Flow Monitor) → `Energy` ✨ **NEW**
- `EnergyMeter` → `Energy`
- `TemperatureController` → `Temperature`
- `WaterMeter` → `Water`
- `PowerMeter` → `Power`
- `AnalogInput` → `Analog`
- `InfoOnlyAnalog` → `Analog` ✨ **NEW**
- `DigitalInput` → `Digital`

### Potentially Missing (Not in your structure file, but could exist)

❓ **Not Currently Handled:**
- `HumiditySensor` → Should map to `Humidity`
- `PressureSensor` → Should map to `Pressure`
- `CO2Sensor` → Should map to `AirQuality`
- `MotionSensor` → Should map to `Motion`
- `LightSensor` → Should map to `Lighting`

**Note:** These are not in your current structure file, so they're not needed yet. If you encounter them, add them to the mapping.

---

## 4. Real-Time Data Storage Frequency

### How It Works

**Storage is event-driven, not time-based:**

1. **Loxone sends updates** when:
   - Sensor values **change** (primary trigger)
   - Periodic updates (if configured in Loxone)
   - System status changes

2. **Our system stores** every value state update it receives:
   - No filtering or throttling
   - Every WebSocket message with identifier `2` (value states) is processed
   - Each measurement gets a timestamp when received

### Frequency Examples

**High-frequency sensors:**
- Temperature sensors: ~1-5 updates per minute (when changing)
- Energy meters: ~1-10 updates per minute (depending on load changes)
- Power meters: ~5-30 updates per minute (rapid power fluctuations)

**Low-frequency sensors:**
- Water meters: ~1 update per hour (or when usage occurs)
- Accumulated values: ~1 update per day (for `totalDay`, `totalWeek`, etc.)

### Storage Characteristics

**Resolution:**
- `resolution_minutes: 0` indicates real-time data (not aggregated)
- Timestamps are precise to the second
- No data loss - every update is stored

**Example Timeline:**
```
10:00:00 - Temperature: 19.18°C → Stored
10:00:15 - Temperature: 19.20°C → Stored (changed)
10:00:30 - Temperature: 19.20°C → Stored (no change, but update received)
10:00:45 - Temperature: 19.22°C → Stored (changed)
```

**Note:** The actual frequency depends on:
- Loxone's update configuration
- Sensor sensitivity settings
- Value change thresholds
- Network conditions

---

## 5. Implementation Summary

### Changes Made

1. ✅ **Category Storage in Sensors**
   - Added `loxone_category_uuid`, `loxone_category_name`, `loxone_category_type` fields

2. ✅ **Category-Based Measurement Type Inference**
   - Priority: Category Type → Category Name → Control Type
   - Handles both structured types (`indoortemperature`) and name-based inference ("Energie")

3. ✅ **Missing Control Types Added**
   - `EFM` → `Energy`
   - `InfoOnlyAnalog` → `Analog`

4. ✅ **Category Info in UUID Mapping**
   - Category info stored in `uuidToSensorMap` for runtime inference
   - SubControls inherit parent category info

### Benefits

- **More accurate measurement types** using semantic category information
- **Better data classification** for analytics and reporting
- **Flexible inference** that works even when category type is "undefined"
- **Backward compatible** - falls back to control type if category unavailable

---

## 6. Example Flow

### Example: "Zähler Hauptanschluss" (Main Meter)

**Control Data:**
```json
{
  "name": "Zähler Hauptanschluss",
  "type": "Meter",
  "cat": "1fa3729e-0098-07da-ffffce026101d865"
}
```

**Category Data:**
```json
{
  "uuid": "1fa3729e-0098-07da-ffffce026101d865",
  "name": "Energie",
  "type": "undefined"
}
```

**Inference Process:**
1. Category type is "undefined" → Skip Priority 1
2. Category name is "Energie" → Matches "Energie" → Returns `Energy` ✅
3. (Fallback not needed)

**Result:**
- `measurementType: 'Energy'`
- `controlType: 'Meter'`
- `categoryInfo: { name: 'Energie', type: 'undefined' }`

---

## 7. Testing

After implementing these changes:

1. **Re-import structure** to populate category fields in sensors
2. **Check measurement types** in stored measurements
3. **Verify category-based inference** works for controls with categories
4. **Confirm fallback** works for controls without categories

---

## Questions Answered

✅ **How do we utilize categories?**
- Categories are stored in sensors and used for priority-based measurement type inference

✅ **Are measurement types and control types the same?**
- No, control types are Loxone-specific, measurement types are our internal classification

✅ **What's missing?**
- Added `EFM` and `InfoOnlyAnalog` mappings
- Category-based inference fills gaps for ambiguous control types

✅ **How frequent is storage?**
- Event-driven: every value state update from Loxone is stored immediately
- Frequency depends on sensor changes and Loxone configuration

