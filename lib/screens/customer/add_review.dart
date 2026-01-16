import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/review_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class AddReviewScreen extends StatefulWidget {
  final OrderModel order;

  const AddReviewScreen({super.key, required this.order});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Create a review for each dish in the order
      for (var dishItem in widget.order.dishItems) {
        final review = ReviewModel(
          reviewId: const Uuid().v4(),
          orderId: widget.order.orderId,
          dishId: dishItem.dishId,
          cookId: widget.order.cookId,
          customerId: authProvider.currentUser!.uid,
          customerName: authProvider.currentUser!.name,
          rating: _rating,
          comment: _commentController.text.trim(),
          createdAt: DateTime.now(),
        );

        await _firestoreService.addReview(review);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Order'),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.order.cookName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Order #${widget.order.orderId.substring(0, 8)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'How was your experience?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  Center(
                    child: RatingBar.builder(
                      initialRating: _rating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 50,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Color(0xFFFC8019),
                      ),
                      onRatingUpdate: (rating) {
                        setState(() => _rating = rating);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _getRatingText(_rating),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFC8019),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Dishes Ordered:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...widget.order.dishItems.map(
                    (item) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFC8019),
                        child: Icon(Icons.restaurant, color: Colors.white),
                      ),
                      title: Text(item.dishName),
                      subtitle: Text('Qty: ${item.quantity}'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Your Review',
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC8019),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text(
                      'Submit Review',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'Excellent! 🌟';
    if (rating >= 3.5) return 'Very Good! 👍';
    if (rating >= 2.5) return 'Good 👌';
    if (rating >= 1.5) return 'Okay 🤔';
    return 'Needs Improvement 😕';
  }
}
