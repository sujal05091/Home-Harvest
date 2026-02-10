import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_router.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Welcome Text
              Text(
                "Welcome to",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              
              // HomeHarvest with Gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF7A18), Color(0xFF3BB78F)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  "HomeHarvest",
                  style: GoogleFonts.pacifico(
                    fontSize: 42,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Lottie Animation
              Lottie.asset(
                'assets/lottie/role_selection.json',
                height: 180,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                "Choose Your Role",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Select how you want to use HomeHarvest",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ROLE CARDS
              RoleCardWithFeatures(
                title: "Customer",
                subtitle: "Order delicious home-cooked meals",
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFFF7A18),
                features: const [
                  "Browse dishes",
                  "Track orders",
                  "Rate cooks",
                ],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRouter.login,
                    arguments: {'role': 'customer'},
                  );
                },
              ),
              const SizedBox(height: 16),

              RoleCardWithFeatures(
                title: "Home Cook",
                subtitle: "Share your culinary creations",
                icon: Icons.restaurant_outlined,
                iconColor: const Color(0xFFE91E63),
                features: const [
                  "List dishes",
                  "Manage orders",
                  "Earn money",
                ],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRouter.login,
                    arguments: {'role': 'cook'},
                  );
                },
              ),
              const SizedBox(height: 16),

              RoleCardWithFeatures(
                title: "Delivery Partner",
                subtitle: "Deliver food and earn flexibly",
                icon: Icons.two_wheeler_outlined,
                iconColor: const Color(0xFF00BCD4),
                features: const [
                  "Flexible hours",
                  "Earn daily",
                  "Get paid fast",
                ],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRouter.login,
                    arguments: {'role': 'rider'},
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ROLE CARD WITH FEATURES WIDGET
class RoleCardWithFeatures extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<String> features;
  final VoidCallback onTap;

  const RoleCardWithFeatures({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.features,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Row: Icon, Title, Arrow
            Row(
              children: [
                // Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Features Row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: features.map((feature) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      feature,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
