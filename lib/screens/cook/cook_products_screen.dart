import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_products_provider.dart';
import '../../models/home_product_model.dart';

class CookProductsScreen extends StatefulWidget {
  const CookProductsScreen({super.key});

  @override
  State<CookProductsScreen> createState() => _CookProductsScreenState();
}

class _CookProductsScreenState extends State<CookProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      context.read<HomeProductsProvider>().loadSellerProducts(uid);
    });
  }

  void _openProductForm({HomeProductModel? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProductFormSheet(existing: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manage Homemade Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFC8019),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        backgroundColor: const Color(0xFFFC8019),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Consumer<HomeProductsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFC8019)));
          }
          if (provider.sellerProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No products yet',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Tap + Add Product to list your first item',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final uid =
                  Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
              context
                  .read<HomeProductsProvider>()
                  .loadSellerProducts(uid);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.sellerProducts.length,
              itemBuilder: (context, i) {
                final product = provider.sellerProducts[i];
                return _CookProductCard(
                  product: product,
                  onEdit: () => _openProductForm(product: product),
                  onDelete: () => _confirmDelete(product),
                  onToggle: () =>
                      provider.toggleAvailability(product),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(HomeProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      await context
          .read<HomeProductsProvider>()
          .deleteProduct(product.productId, uid);
    }
  }
}

// ── Cook Product Card ─────────────────────────────────────────────────────────

class _CookProductCard extends StatelessWidget {
  final HomeProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _CookProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: product.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Toggle availability
                      Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: product.isAvailable,
                          onChanged: (_) => onToggle(),
                          activeColor: const Color(0xFFFC8019),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    product.category,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFC8019),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        product.isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          color: product.isAvailable
                              ? const Color(0xFF27AE60)
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(Icons.edit_outlined,
                            size: 18, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
      color: Colors.grey[200],
      child:
          const Center(child: Icon(Icons.inventory_2, color: Colors.grey)));
}

// ── Product Form Sheet ────────────────────────────────────────────────────────

class _ProductFormSheet extends StatefulWidget {
  final HomeProductModel? existing;
  const _ProductFormSheet({this.existing});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _description;
  late TextEditingController _ingredients;
  late TextEditingController _workplace;
  late TextEditingController _imageUrl;
  late TextEditingController _stock;
  String _category = 'Pickles';
  bool _isSaving = false;

  static const _categories = [
    'Pickles',
    'Snacks',
    'Masala & Spices',
    'Papad',
    'Sweets & Desserts',
    'Herbal',
    'Beverages',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(0) : '');
    _description =
        TextEditingController(text: p?.description ?? '');
    _ingredients =
        TextEditingController(text: p?.ingredients ?? '');
    _workplace = TextEditingController(text: p?.workplace ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _stock = TextEditingController(
        text: p != null ? p.stock.toString() : '');
    _category = p?.category ?? 'Pickles';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _description,
      _ingredients,
      _workplace,
      _imageUrl,
      _stock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);
    final provider =
        Provider.of<HomeProductsProvider>(context, listen: false);
    final uid = authProvider.currentUser!.uid;
    final name =
        authProvider.currentUser?.name ?? 'Home Seller';

    final product = HomeProductModel(
      productId: widget.existing?.productId ?? '',
      sellerId: uid,
      sellerName: name,
      name: _name.text.trim(),
      category: _category,
      price: double.tryParse(_price.text.trim()) ?? 0,
      description: _description.text.trim(),
      ingredients: _ingredients.text.trim(),
      workplace: _workplace.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      verifiedSeller: widget.existing?.verifiedSeller ?? false,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      isAvailable: widget.existing?.isAvailable ?? true,
      rating: widget.existing?.rating ?? 0,
      totalRatings: widget.existing?.totalRatings ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (widget.existing != null) {
      success = await provider.updateProduct(product);
    } else {
      success = await provider.addProduct(product);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${product.name} saved!'
              : 'Failed to save product'),
          backgroundColor:
              success ? const Color(0xFF27AE60) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Text(
                    isEdit ? 'Edit Product' : 'Add Product',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              _field(_name, 'Product Name *',
                  validator: (v) =>
                      v!.isEmpty ? 'Required' : null),
              _field(_price, 'Price (₹) *',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v!.isEmpty ? 'Required' : null),

              // Category dropdown
              const Text('Category *',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _inputDecoration('Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),

              _field(_description, 'Description',
                  maxLines: 2),
              _field(_ingredients, 'Ingredients Used'),
              _field(_workplace, 'Preparation Place'),
              _field(_imageUrl, 'Product Image URL'),
              _field(_stock, 'Stock Quantity',
                  keyboardType: TextInputType.number),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(
                          isEdit ? 'Update Product' : 'Add Product',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFC8019), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
