import 'package:flutter/material.dart';

/// Shared navigation drawer used across Home, Library, Settings, and Support.
///
/// Replaces the previously copy-pasted ~125 lines of identical drawer code
/// that existed in each page individually.
class ShogunifyDrawer extends StatelessWidget {
  const ShogunifyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 25, 25, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replaced DrawerHeader with Container to fix the full-width line issue and remove excess padding
          Container(
            padding: const EdgeInsets.only(left: 20, top: 50, bottom: 20),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Aligns logo + text to the left
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/Icon6.jpg',
                      height: 65,
                      width: 65,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'shogunify',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v1.0.4',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Optional: Add a custom, controlled divider if you still want a line below the header
          Divider(
            color: Colors.white.withOpacity(0.2),
            thickness: 1,
            indent: 20, // Controls line start padding on the left
            endIndent: 20, // Controls line end padding on the right
          ),

          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
            leading: const Icon(
              Icons.home_rounded,
              size: 30,
              color: Colors.white,
            ),
            title: const Text(
              'Home',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/library');
            },
            leading: const Icon(
              Icons.format_list_bulleted_rounded,
              size: 30,
              color: Colors.white,
            ),
            title: const Text(
              'Library',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/support');
            },
            leading: const Icon(
              Icons.attach_money_outlined,
              size: 30,
              color: Colors.white,
            ),
            title: const Text(
              'Support dev',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/settings');
            },
            leading: const Icon(
              Icons.settings,
              size: 30,
              color: Colors.white,
            ),
            title: const Text(
              'Settings',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
