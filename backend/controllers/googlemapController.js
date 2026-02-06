const axios = require('axios');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * Places Autocomplete endpoint
 * GET /api/v1/googlemap/places/autocomplete
 * 
 * Query parameters:
 * - input (required): The text string on which to search
 */
exports.getPlacesAutocomplete = asyncHandler(async (req, res) => {
  const { input } = req.query;

  if (!input) {
    return res.status(400).json({ 
      success: false,
      error: 'input query parameter is required' 
    });
  }

  const url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  try {
    const response = await axios.get(url, {
      params: {
        input,
        key: process.env.GOOGLE_API_KEY,
      },
    });

    res.json({
      success: true,
      data: response.data
    });
  } catch (error) {
    console.error('Google Maps API Error:', error?.response?.data || error.message);
    
    // Return the error from Google API if available, otherwise generic error
    const errorMessage = error?.response?.data?.error_message || 'Failed to fetch places from Google Maps API';
    const statusCode = error?.response?.status || 500;
    
    res.status(statusCode).json({ 
      success: false,
      error: errorMessage 
    });
  }
});
