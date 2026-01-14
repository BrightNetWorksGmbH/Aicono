class VerseEntity {
  final String id;
  final String name;
  final String? subdomain;
  final String? organizationName;
  final String adminEmail;
  final bool isSetupComplete;
  final bool canCreateBrytesight;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VerseEntity({
    required this.id,
    required this.name,
    this.subdomain,
    this.organizationName,
    required this.adminEmail,
    required this.isSetupComplete,
    required this.canCreateBrytesight,
    required this.createdAt,
    this.updatedAt,
  });
}

class CreateVerseRequest {
  final String name;
  final String adminEmail;
  final String firstName;
  final String lastName;
  final String position;
  final String subdomain;

  CreateVerseRequest({
    required this.name,
    required this.adminEmail,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.subdomain,
  });

  Map<String, dynamic> toJson() {
    return {
      'organization_name': name,
      'owner_email': adminEmail,
      'first_name': firstName,
      'last_name': lastName,
      'position': position,
      'sub_domain': subdomain,
    };
  }
}

class CreateVerseResponse {
  final String message;
  final VerseEntity verse;
  final String invitationToken;

  CreateVerseResponse({
    required this.message,
    required this.verse,
    required this.invitationToken,
  });

  factory CreateVerseResponse.fromJson(Map<String, dynamic> json) {
    // Handle new API response structure with nested data
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final bryteSwitchData = data['bryteSwitch'] as Map<String, dynamic>;
    final invitationData = data['invitation'] as Map<String, dynamic>;

    return CreateVerseResponse(
      message: json['message'] as String,
      verse: VerseEntity(
        id: bryteSwitchData['_id'] as String,
        name: bryteSwitchData['organization_name'] as String,
        subdomain: bryteSwitchData['sub_domain'] as String?,
        organizationName: bryteSwitchData['organization_name'] as String?,
        adminEmail: bryteSwitchData['owner_email'] as String,
        isSetupComplete: bryteSwitchData['is_setup_complete'] as bool? ?? false,
        canCreateBrytesight:
            false, // Not provided in response, default to false
        createdAt: DateTime.parse(bryteSwitchData['created_at'] as String),
        updatedAt: bryteSwitchData['updated_at'] != null
            ? DateTime.parse(bryteSwitchData['updated_at'] as String)
            : null,
      ),
      invitationToken: invitationData['token'] as String,
    );
  }
}
