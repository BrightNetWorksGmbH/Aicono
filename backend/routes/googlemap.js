const express = require('express');
const router = express.Router();
const googlemapController = require('../controllers/googlemapController');

// Places Autocomplete endpoint (public, no auth required)
router.get('/places/autocomplete', googlemapController.getPlacesAutocomplete);

module.exports = router;
