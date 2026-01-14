import 'package:flutter/material.dart';

class BuildingHeader extends StatelessWidget {
  final String? userName;
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  const BuildingHeader({
    super.key,
    this.userName,
    this.onMenuTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile picture
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          ),
          // Logo
          Row(
            children: [
              Text(
                'BRYTE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              Text(
                'SWITCH',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          // Menu
          GestureDetector(
            onTap: onMenuTap,
            child: Column(
              children: [
                Text(
                  'MENU',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.menu, color: Colors.grey[700]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

