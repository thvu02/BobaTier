import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/map/providers/shop_detail_provider.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';

class RateDrinkScreen extends ConsumerStatefulWidget {
  final String placeId;
  final String? drinkId;
  const RateDrinkScreen({super.key, required this.placeId, this.drinkId});

  @override
  ConsumerState<RateDrinkScreen> createState() => _RateDrinkScreenState();
}

class _RateDrinkScreenState extends ConsumerState<RateDrinkScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  double _score = 7.5;
  bool _submitting = false;
  bool _prefilled = false;
  File? _pickedImage;

  bool get _isEditing => widget.drinkId != null;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path, '${picked.path}_c.jpg', minWidth: 1200, quality: 80,
    );
    setState(() => _pickedImage = File(compressed?.path ?? picked.path));
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a drink name')));
      return;
    }
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final rankRef = db.collection('users').doc(uid).collection('rankings').doc(widget.placeId);

      String? photoUrl;
      String? thumbnailUrl;
      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance.ref('drinks/$uid/${const Uuid().v4()}.jpg');
        await storageRef.putFile(_pickedImage!);
        photoUrl = await storageRef.getDownloadURL();
      }

      final doc = await rankRef.get();

      if (_isEditing && _pickedImage == null && doc.exists) {
        final existingDrinks = doc.data()!['drinks'] as List<dynamic>;
        final existingDrink = existingDrinks.cast<Map<String, dynamic>>()
            .where((d) => d['id'] == widget.drinkId).firstOrNull;
        if (existingDrink != null) {
          photoUrl = existingDrink['photoUrl'] as String?;
          thumbnailUrl = existingDrink['thumbnailUrl'] as String?;
        }
      }

      final newDrink = {
        'id': _isEditing ? widget.drinkId : const Uuid().v4(),
        'name': _nameController.text,
        'score': _score,
        'price': _priceController.text.isNotEmpty ? _priceController.text : null,
        'photoUrl': photoUrl,
        'thumbnailUrl': thumbnailUrl,
        'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
        'createdAt': Timestamp.now(),
      };

      if (doc.exists) {
        final existing = doc.data()!;
        final List<dynamic> drinks;
        if (_isEditing) {
          drinks = (existing['drinks'] as List<dynamic>).map((d) =>
            (d as Map<String, dynamic>)['id'] == widget.drinkId ? newDrink : d
          ).toList();
        } else {
          drinks = [...(existing['drinks'] as List<dynamic>), newDrink];
        }
        final scores = drinks.map((d) => ((d as Map<String, dynamic>)['score'] as num).toDouble()).toList();
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        await rankRef.update({
          'drinks': drinks,
          'avgDrinkScore': (avg * 10).round() / 10,
          'drinkCount': drinks.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final shopDoc = await db.collection('shops').doc(widget.placeId).get();
        final shopData = shopDoc.data() ?? {};
        await rankRef.set({
          'tier': 'C',
          'shopName': shopData['name'] ?? '',
          'shopAddress': shopData['address'] ?? '',
          'googleRating': shopData['googleRating'] ?? 0,
          'coordinates': shopData['coordinates'] ?? {'lat': 0, 'lng': 0},
          'drinks': [newDrink],
          'avgDrinkScore': _score,
          'drinkCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Review updated!' : 'Review submitted!'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final message = switch (e.plugin) {
          'firebase_storage' => 'Photo upload failed. Please try again.',
          _ => 'Could not save your review. Please try again.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopDetailProvider(widget.placeId));
    final existing = ref.watch(shopRankingProvider(widget.placeId));

    if (!_prefilled && _isEditing && existing != null) {
      final drink = existing.drinks.where((d) => d.id == widget.drinkId).firstOrNull;
      if (drink != null) {
        _nameController.text = drink.name;
        _priceController.text = drink.price ?? '';
        _notesController.text = drink.notes ?? '';
        _score = drink.score;
        _prefilled = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit drink' : 'Rate a drink'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shopAsync.when(
              data: (shop) => shop != null
                  ? Text('${shop.name} · ${shop.address.split(",").first}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(12),
                  image: _pickedImage != null ? DecorationImage(
                    image: FileImage(_pickedImage!), fit: BoxFit.cover,
                  ) : null,
                ),
                child: _pickedImage == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.textSecondary),
                  SizedBox(height: 6),
                  Text('Tap to add a photo', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ])
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Drink name'), inputFormatters: [LengthLimitingTextInputFormatter(100)]),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(hintText: 'Price (e.g. 5.50)', prefixIcon: Icon(Icons.attach_money, size: 20)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                LengthLimitingTextInputFormatter(7),
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Drink rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
              Text(_score.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary, inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.primary, overlayColor: AppColors.primary.withValues(alpha: 0.1), trackHeight: 4,
              ),
              child: Slider(value: _score, min: 1.0, max: 10.0, divisions: 90, onChanged: (v) => setState(() => _score = v)),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('1.0', style: Theme.of(context).textTheme.bodySmall),
              Text('10.0', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(hintText: 'Add a note (optional)...'), inputFormatters: [LengthLimitingTextInputFormatter(500)]),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Update review' : 'Submit review'),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
