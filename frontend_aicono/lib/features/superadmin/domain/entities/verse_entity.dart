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
      'name': name,
      'admin_email': adminEmail,
      'first_name': firstName,
      'last_name': lastName,
      'position': position,
      'subdomain': subdomain,
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
    final verseData = json['verse'] as Map<String, dynamic>;
    final invitationData = json['invitation'] as Map<String, dynamic>;

    return CreateVerseResponse(
      message: json['message'] as String,
      verse: VerseEntity(
        id: verseData['_id'] as String,
        name: verseData['name'] as String,
        subdomain: verseData['subdomain'] as String?,
        organizationName: verseData['organization_name'] as String?,
        adminEmail: verseData['admin_email'] as String,
        isSetupComplete: verseData['is_setup_complete'] as bool,
        canCreateBrytesight:
            verseData['can_create_brytesight'] as bool? ?? false,
        createdAt: DateTime.parse(verseData['created_at'] as String),
        updatedAt: verseData['updated_at'] != null
            ? DateTime.parse(verseData['updated_at'] as String)
            : null,
      ),
      invitationToken: invitationData['token'] as String,
    );
  }
}
