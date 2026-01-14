import 'package:equatable/equatable.dart';

class BuildingEntity extends Equatable {
  final String? id;
  final String name;
  final String? address;
  final String? description;
  final String? buildingType;
  final int? numberOfFloors;
  final int? numberOfRooms;
  final double? totalArea;
  final String? constructionYear;
  final String? status; // e.g., 'draft', 'in_progress', 'completed'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BuildingEntity({
    this.id,
    required this.name,
    this.address,
    this.description,
    this.buildingType,
    this.numberOfFloors,
    this.numberOfRooms,
    this.totalArea,
    this.constructionYear,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  BuildingEntity copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    String? buildingType,
    int? numberOfFloors,
    int? numberOfRooms,
    double? totalArea,
    String? constructionYear,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuildingEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      buildingType: buildingType ?? this.buildingType,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      numberOfRooms: numberOfRooms ?? this.numberOfRooms,
      totalArea: totalArea ?? this.totalArea,
      constructionYear: constructionYear ?? this.constructionYear,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        description,
        buildingType,
        numberOfFloors,
        numberOfRooms,
        totalArea,
        constructionYear,
        status,
        createdAt,
        updatedAt,
      ];
}

