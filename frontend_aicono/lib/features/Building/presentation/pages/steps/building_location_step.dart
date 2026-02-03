import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:dio/dio.dart';

class BuildingLocationStep extends StatefulWidget {
  final BuildingEntity building;
  final Function(BuildingEntity) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const BuildingLocationStep({
    super.key,
    required this.building,
    required this.onUpdate,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<BuildingLocationStep> createState() => _BuildingLocationStepState();
}

class _BuildingLocationStepState extends State<BuildingLocationStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressController;
  final Dio _dio = Dio();

  // TODO: Replace with your Google Places API key
  // You should store this securely, e.g., in environment variables or secure storage
  static const String _googlePlacesApiKey =
      'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao';

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.building.address ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _dio.close();
    super.dispose();
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      final updatedBuilding = widget.building.copyWith(
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      widget.onUpdate(updatedBuilding);
      widget.onNext();
    }
  }

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.isEmpty ||
        _googlePlacesApiKey == 'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao') {
      return [];
    }

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _googlePlacesApiKey,
          'types': 'address|establishment',
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        return predictions
            .map(
              (prediction) => {
                'place_id': prediction['place_id'],
                'description': prediction['description'],
                'main_text': prediction['structured_formatting']['main_text'],
                'secondary_text':
                    prediction['structured_formatting']['secondary_text'],
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    if (_googlePlacesApiKey == 'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao') {
      return null;
    }

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _googlePlacesApiKey,
          'fields': 'formatted_address,geometry,name',
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final result = response.data['result'];
        return {
          'formatted_address': result['formatted_address'],
          'name': result['name'],
          'location': result['geometry']['location'],
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  void _showPlaceSearchDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void performSearch(String query) async {
            if (query.isEmpty) {
              setDialogState(() {
                searchResults = [];
                isLoading = false;
              });
              return;
            }

            setDialogState(() {
              isLoading = true;
            });

            final results = await _searchPlaces(query);
            setDialogState(() {
              searchResults = results;
              isLoading = false;
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        'Search Places',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      // Debounce search
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (searchController.text == value) {
                          performSearch(value);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Results list
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : searchResults.isEmpty
                        ? Center(
                            child: Text(
                              searchController.text.isEmpty
                                  ? 'Start typing to search...'
                                  : 'No results found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final place = searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on),
                                title: Text(
                                  place['main_text'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  place['secondary_text'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () async {
                                  // Get place details and update address
                                  final details = await _getPlaceDetails(
                                    place['place_id'],
                                  );
                                  if (details != null && mounted) {
                                    _addressController.text =
                                        details['formatted_address'] ?? '';
                                    final updatedBuilding = widget.building
                                        .copyWith(
                                          address: details['formatted_address'],
                                        );
                                    widget.onUpdate(updatedBuilding);
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Location',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Where is this building located?',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter building address (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 3,

              onChanged: (_) {
                final updatedBuilding = widget.building.copyWith(
                  address: _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
                );
                widget.onUpdate(updatedBuilding);
              },
            ),
            ElevatedButton.icon(
              onPressed: _showPlaceSearchDialog,
              icon: const Icon(Icons.search),
              label: const Text('Search Places'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAndNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
