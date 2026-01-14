import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingSummaryStep extends StatelessWidget {
  final BuildingEntity building;
  final VoidCallback onPrevious;
  final VoidCallback onSave;

  const BuildingSummaryStep({
    super.key,
    required this.building,
    required this.onPrevious,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review your building information before saving',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow(
                        'Name',
                        building.name,
                        Icons.business,
                      ),
                      if (building.description != null)
                        _buildSummaryRow(
                          'Description',
                          building.description!,
                          Icons.description,
                        ),
                      if (building.address != null)
                        _buildSummaryRow(
                          'Address',
                          building.address!,
                          Icons.location_on,
                        ),
                      if (building.buildingType != null)
                        _buildSummaryRow(
                          'Building Type',
                          building.buildingType!,
                          Icons.category,
                        ),
                      if (building.numberOfFloors != null)
                        _buildSummaryRow(
                          'Number of Floors',
                          building.numberOfFloors.toString(),
                          Icons.layers,
                        ),
                      if (building.totalArea != null)
                        _buildSummaryRow(
                          'Total Area',
                          '${building.totalArea} sq ft',
                          Icons.square_foot,
                        ),
                      if (building.constructionYear != null)
                        _buildSummaryRow(
                          'Construction Year',
                          building.constructionYear!,
                          Icons.calendar_today,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Building'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

