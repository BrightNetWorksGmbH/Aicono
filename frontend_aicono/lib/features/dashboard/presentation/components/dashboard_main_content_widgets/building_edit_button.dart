import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';

/// Button that saves building form data via API (PATCH building).
class BuildingEditButton extends StatefulWidget {
  final String buildingId;
  final TextEditingController buildingNameController;
  final TextEditingController buildingTypeController;
  final TextEditingController numberOfFloorsController;
  final TextEditingController totalAreaController;
  final TextEditingController constructionYearController;
  final TextEditingController loxoneUserController;
  final TextEditingController loxonePassController;
  final TextEditingController loxoneExternalAddressController;
  final TextEditingController loxonePortController;
  final TextEditingController loxoneSerialNumberController;
  final VoidCallback onSuccess;

  const BuildingEditButton({
    super.key,
    required this.buildingId,
    required this.buildingNameController,
    required this.buildingTypeController,
    required this.numberOfFloorsController,
    required this.totalAreaController,
    required this.constructionYearController,
    required this.loxoneUserController,
    required this.loxonePassController,
    required this.loxoneExternalAddressController,
    required this.loxonePortController,
    required this.loxoneSerialNumberController,
    required this.onSuccess,
  });

  @override
  State<BuildingEditButton> createState() => _BuildingEditButtonState();
}

class _BuildingEditButtonState extends State<BuildingEditButton> {
  bool _isLoading = false;

  Future<void> _handleSave() async {
    final buildingName = widget.buildingNameController.text.trim();

    if (buildingName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'name': buildingName};

      if (widget.buildingTypeController.text.trim().isNotEmpty) {
        requestBody['type_of_use'] =
            widget.buildingTypeController.text.trim();
      }

      if (widget.numberOfFloorsController.text.trim().isNotEmpty) {
        final numFloors =
            int.tryParse(widget.numberOfFloorsController.text.trim());
        if (numFloors != null) {
          requestBody['num_floors'] = numFloors;
        }
      }

      if (widget.totalAreaController.text.trim().isNotEmpty) {
        final totalArea =
            double.tryParse(widget.totalAreaController.text.trim());
        if (totalArea != null) {
          requestBody['building_size'] = totalArea.toInt();
        }
      }

      if (widget.constructionYearController.text.trim().isNotEmpty) {
        final year =
            int.tryParse(widget.constructionYearController.text.trim());
        if (year != null) {
          requestBody['year_of_construction'] = year;
        }
      }

      requestBody['miniserver_user'] = widget.loxoneUserController.text.trim();
      requestBody['miniserver_pass'] = widget.loxonePassController.text.trim();
      requestBody['miniserver_external_address'] =
          widget.loxoneExternalAddressController.text.trim();
      final port =
          int.tryParse(widget.loxonePortController.text.trim()) ?? 443;
      requestBody['miniserver_port'] = port;
      requestBody['miniserver_serial'] =
          widget.loxoneSerialNumberController.text.trim();

      final response = await dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Building updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update building: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating building: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : PrimaryOutlineButton(
            label: 'Save Changes',
            width: 260,
            onPressed: _handleSave,
          );
  }
}
