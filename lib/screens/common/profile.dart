import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    child: Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(user.email, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text(user.phone, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Role'),
                      subtitle: Text(user.role.toUpperCase()),
                    ),
                  ),
                  if (user.role == 'cook')
                    Card(
                      child: ListTile(
                        leading: Icon(
                          user.verified ? Icons.verified : Icons.pending,
                          color: user.verified ? Colors.green : Colors.orange,
                        ),
                        title: const Text('Verification Status'),
                        subtitle: Text(user.verified ? 'Verified' : 'Pending'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  
                  // Customer Options
                  if (user.role == 'customer') ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Color(0xFFFC8019)),
                        title: const Text('Order History'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pushNamed(context, AppRouter.orderHistory),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on, color: Color(0xFFFC8019)),
                        title: const Text('Saved Addresses'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pushNamed(context, AppRouter.selectAddress),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await authProvider.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRouter.roleSelect,
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
