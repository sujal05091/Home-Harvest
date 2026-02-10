import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../app_router.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Lottie.asset(
                'assets/lottie/role_selection.json',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to HomeHarvest',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Select your role to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                icon: Icons.person,
                title: 'Customer',
                subtitle: 'Order home-cooked meals',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.login,
                  arguments: {'role': 'customer'},
                ),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.restaurant_menu,
                title: 'Home Cook',
                subtitle: 'Sell your delicious food',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.login,
                  arguments: {'role': 'cook'},
                ),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.two_wheeler,
                title: 'Delivery Partner',
                subtitle: 'Deliver and earn',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.login,
                  arguments: {'role': 'rider'},
                ),
              ),
              const SizedBox(height: 30),
              
              // Map Test Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.mapTest),
                    icon: const Icon(Icons.map, color: Colors.orange),
                    label: const Text(
                      'Google Maps',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.osmTest),
                    icon: const Icon(Icons.map_outlined, color: Colors.green),
                    label: const Text(
                      '🗺️ OpenStreetMap FREE',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xFFFC8019)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}
