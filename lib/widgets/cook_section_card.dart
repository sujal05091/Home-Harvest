import 'package:flutter/material.dart';
import '../models/cook_section_model.dart';
import '../models/dish_model.dart';

/// Cook section card with horizontal scrolling dishes
/// Shows cook profile, rating, and their available dishes
class CookSectionCard extends StatelessWidget {
  final CookSectionModel cookSection;
  final Function(DishModel) onDishTap;
  final Widget Function(DishModel) dishCardBuilder;

  const CookSectionCard({
    super.key,
    required this.cookSection,
    required this.onDishTap,
    required this.dishCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12), // Increased vertical spacing between cook sections
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cook Header Card
          _buildCookHeader(context),
          
          SizedBox(height: 12),
          
          // Horizontal Dishes Scroll
          _buildDishesHorizontalScroll(context),
        ],
      ),
    );
  }

  /// Cook profile header with name, rating, distance (no photo)
  Widget _buildCookHeader(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cook Info (Expanded Middle Section)
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cook Name with Verified Badge
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      child: Text(
                        cookSection.cookName,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E3333),
                          letterSpacing: 0.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cookSection.isVerified) ...[
                      SizedBox(width: 6),
                      Icon(
                        Icons.verified,
                        color: Color(0xFF0FA958),
                        size: 18,
                      ),
                    ],
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Rating and Time/Distance
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Rating
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          cookSection.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E3333),
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(width: 10),
                    
                    // Distance or Time
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (cookSection.distanceInKm != null) ...[
                          Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFFFC8019),
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${cookSection.distanceInKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF686B78),
                              letterSpacing: 0.0,
                            ),
                          ),
                        ] else if (cookSection.estimatedTimeMinutes != null) ...[
                          Icon(
                            Icons.access_time,
                            color: Color(0xFFFC8019),
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${cookSection.estimatedTimeMinutes} Minute',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF686B78),
                              letterSpacing: 0.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(width: 10),
          
          // Dish Count Badge (Right Side)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${cookSection.totalDishes}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFC8019),
                          letterSpacing: 0.0,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        'dishes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF686B78),
                          letterSpacing: 0.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal scrolling list of dishes
  Widget _buildDishesHorizontalScroll(BuildContext context) {
    return SizedBox(
      height: 260, // Fixed height for horizontal scroll
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        itemCount: cookSection.dishes.length,
        itemBuilder: (context, index) {
          final dish = cookSection.dishes[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), // Increased gap between cards
            child: SizedBox(
              width: 200, // Updated to match card width
              child: GestureDetector(
                onTap: () => onDishTap(dish),
                child: dishCardBuilder(dish),
              ),
            ),
          );
        },
      ),
    );
  }
}
