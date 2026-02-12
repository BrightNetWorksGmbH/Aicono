/// Request payload for updating user profile via PUT /api/v1/users/me.
class ProfileUpdateRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String position;
  final String? profilePictureUrl;

  ProfileUpdateRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.position,
    this.profilePictureUrl,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        if (phoneNumber != null && phoneNumber!.isNotEmpty) 'phone_number': phoneNumber,
        'position': position,
        if (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
          'profile_picture_url': profilePictureUrl,
      };
}
