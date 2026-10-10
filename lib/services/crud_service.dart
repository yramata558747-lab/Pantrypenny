import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pantry_item.dart';

class PickedImage {
  final File file;
  final String url;

  PickedImage({required this.file, required this.url});
}

/// Firestore CRUD + Cloudinary image upload (as in the course slides).
///
/// Pantry items are stored per user at:
///   users/{uid}/pantry/{cloudId}
class CrudService {
  // ------------------------------------------------------------
  // CLOUDINARY SETTINGS - replace with YOUR values from the
  // Cloudinary dashboard (Cloud name + UNSIGNED upload preset).
  // ------------------------------------------------------------
  static const String cloudName = 'YOUR_CLOUD_NAME';
  static const String uploadPreset = 'YOUR_UNSIGNED_PRESET';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  final ImagePicker _picker = ImagePicker();

  // ------------------------------------------------------------
  // CURRENT USER COLLECTION
  // ------------------------------------------------------------
  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => _uid != null;

  CollectionReference<Map<String, dynamic>>? get _items {
    final uid = _uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pantry');
  }

  // ------------------------------------------------------------
  // IMAGE: pick from gallery and upload to Cloudinary
  // Returns null when the user cancels.
  // ------------------------------------------------------------
  Future<PickedImage?> pickImageForAddItem() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedFile == null) return null;

    final file = File(pickedFile.path);

    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return PickedImage(file: file, url: response.secureUrl);
  }

  // ------------------------------------------------------------
  // CREATE + UPDATE (same call: set with merge)
  // ------------------------------------------------------------
  Future<void> upsertItem(PantryItem item) async {
    final items = _items;

    if (items == null || item.cloudId.isEmpty) return;

    await items.doc(item.cloudId).set({
      'name': item.name,
      'quantity': item.fullPackagesRemaining,
      'amount': item.amount,
      'unit': item.unit,
      'category': item.category,
      'location': item.location,
      'package_count': item.packageCount,
      'package_size': item.packageSize,
      'package_type': item.packageType,
      'price_per_package': item.pricePerPackage,
      'total_price': item.totalPrice,
      'purchase_date': Timestamp.fromDate(item.purchaseDate),
      'image_url':
          item.imageUrl.isEmpty ? null : item.imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // READ (real-time stream)
  // ------------------------------------------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> getItems() {
    final items = _items;

    if (items == null) {
      return const Stream.empty();
    }

    return items
        .orderBy('purchase_date', descending: true)
        .snapshots();
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------
  Future<void> deleteItem(String cloudId) async {
    final items = _items;

    if (items == null || cloudId.isEmpty) return;

    await items.doc(cloudId).delete();
  }

  Future<void> deleteAllItems() async {
    final items = _items;

    if (items == null) return;

    final snapshot = await items.get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}