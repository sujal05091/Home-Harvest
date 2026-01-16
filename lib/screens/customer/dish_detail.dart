import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dishes_provider.dart';
import '../../providers/orders_provider.dart';

class DishDetailScreen extends StatefulWidget {
  final String dishId;

  const DishDetailScreen({super.key, required this.dishId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final dishesProvider = Provider.of<DishesProvider>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);

    return FutureBuilder(
      future: dishesProvider.getDishById(widget.dishId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final dish = snapshot.data!;

        return Scaffold(
          appBar: AppBar(title: Text(dish.title)),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dish image placeholder
                Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.restaurant, size: 100)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${dish.price}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFFFC8019),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(dish.description),
                      const SizedBox(height: 20),
                      Text(
                        'By ${dish.cookName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ordersProvider.addToCart(dish);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );
                          },
                          child: const Text('Add to Cart'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
