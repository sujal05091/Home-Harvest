import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/dish_model.dart';
import '../services/firestore_service.dart';

class OrdersProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<OrderModel> _orders = [];
  List<OrderItem> _cartItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get orders => _orders;
  List<OrderItem> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get cartItemCount => _cartItems.length;

  double get cartTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Load customer orders
  void loadCustomerOrders(String customerId) {
    _isLoading = true;
    notifyListeners();

    _firestoreService.getCustomerOrders(customerId).listen(
      (orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Load cook orders
  void loadCookOrders(String cookId) {
    _isLoading = true;
    notifyListeners();

    _firestoreService.getCookOrders(cookId).listen(
      (orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cart operations
  void addToCart(DishModel dish, {int quantity = 1}) {
    // Check if dish already in cart
    int existingIndex = _cartItems.indexWhere((item) => item.dishId == dish.dishId);

    if (existingIndex != -1) {
      _cartItems[existingIndex] = OrderItem(
        dishId: dish.dishId,
        dishName: dish.title,
        price: dish.price,
        quantity: _cartItems[existingIndex].quantity + quantity,
      );
    } else {
      _cartItems.add(OrderItem(
        dishId: dish.dishId,
        dishName: dish.title,
        price: dish.price,
        quantity: quantity,
      ));
    }

    notifyListeners();
  }

  void removeFromCart(String dishId) {
    _cartItems.removeWhere((item) => item.dishId == dishId);
    notifyListeners();
  }

  void updateCartItemQuantity(String dishId, int quantity) {
    int index = _cartItems.indexWhere((item) => item.dishId == dishId);
    if (index != -1) {
      if (quantity <= 0) {
        removeFromCart(dishId);
      } else {
        _cartItems[index] = OrderItem(
          dishId: _cartItems[index].dishId,
          dishName: _cartItems[index].dishName,
          price: _cartItems[index].price,
          quantity: quantity,
        );
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // Create order
  Future<String?> createOrder(OrderModel order) async {
    try {
      _isLoading = true;
      notifyListeners();

      String orderId = await _firestoreService.createOrder(order);

      _isLoading = false;
      clearCart(); // Clear cart after successful order
      notifyListeners();

      return orderId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      int index = _orders.indexWhere((order) => order.orderId == orderId);
      if (index != -1) {
        OrderModel updatedOrder = _orders[index].copyWith(
          status: newStatus,
          acceptedAt: newStatus == OrderStatus.ACCEPTED ? DateTime.now() : _orders[index].acceptedAt,
          pickedUpAt: newStatus == OrderStatus.PICKED_UP ? DateTime.now() : _orders[index].pickedUpAt,
          deliveredAt: newStatus == OrderStatus.DELIVERED ? DateTime.now() : _orders[index].deliveredAt,
        );

        await _firestoreService.updateOrder(updatedOrder);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Cancel order
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      int index = _orders.indexWhere((order) => order.orderId == orderId);
      if (index != -1) {
        OrderModel updatedOrder = _orders[index].copyWith(
          status: OrderStatus.CANCELLED,
          cancellationReason: reason,
        );

        await _firestoreService.updateOrder(updatedOrder);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
