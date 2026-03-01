// services/ad_service.dart
import 'package:firebase_database/firebase_database.dart';
import '../models/ad_model.dart';

class AdService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // İlanı güncelle
  Future<void> updateAd(Ad ad) async {
    try {
      await _database.child('ads').child(ad.id).update(ad.toMap());
    } catch (e) {
      print('İlan güncelleme hatası: $e');
      rethrow;
    }
  }

  // İlanı ID'ye göre getir
  Future<Ad?> getAdById(String adId) async {
    try {
      final snapshot = await _database.child('ads').child(adId).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        return Ad.fromMap(data, adId);
      }
      return null;
    } catch (e) {
      print('İlan getirme hatası: $e');
      return null;
    }
  }
}