import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Kullanıcı oluştur
  Future<void> createUserProfile(String userId, String email) async {
    try {
      await _database.child('users').child(userId).set({
        'email': email,
        'isPremium': false,
        'premiumExpiry': null,
        'premiumPlan': null,
        'premiumPurchaseDate': null,
        'adsCount': 0,
        'singleAdCount': 0,
        'totalSpent': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
        'subscriptionStatus': 'none',
        'paymentMethod': 'google_play',
        'country': 'TR',
        'currency': 'TRY',
        'adsLimit': 0,
        'currentAds': 0,
      });
      print('✅ Kullanıcı profili oluşturuldu: $userId');
    } catch (e) {
      print('❌ Kullanıcı profili oluşturma hatası: $e');
      rethrow;
    }
  }

  // Kullanıcının premium durumunu kontrol et
  Future<bool> canPublishAd(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        final isPremium = data['isPremium'] ?? false;

        if (isPremium) {
          final expiry = data['premiumExpiry'];
          if (expiry != null) {
            final expiryDate = DateTime.parse(expiry);
            if (expiryDate.isAfter(DateTime.now())) {
              return true;
            } else {
              await _updatePremiumStatus(userId, false);
              return false;
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ Premium durum kontrol hatası: $e');
      return false;
    }
  }

  // Premium durumu güncelle
  Future<void> _updatePremiumStatus(String userId, bool isPremium) async {
    try {
      await _database.child('users').child(userId).update({
        'isPremium': isPremium,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Premium durum güncelleme hatası: $e');
    }
  }

  // Kullanıcı bilgilerini getir
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ Kullanıcı bilgileri getirme hatası: $e');
      return null;
    }
  }

  // Premium plan satın al
  Future<void> purchasePremiumPlan(String userId, String plan, String transactionId) async {
    try {
      final now = DateTime.now();
      final expiryDate = plan == 'monthly'
          ? now.add(Duration(days: 30))
          : now.add(Duration(days: 365));

      // Kullanıcı ana bilgilerini güncelle
      await _database.child('users').child(userId).update({
        'isPremium': true,
        'premiumExpiry': expiryDate.toIso8601String(),
        'premiumPlan': plan,
        'premiumPurchaseDate': now.toIso8601String(),
        'lastUpdated': now.toIso8601String(),
        'adsLimit': plan == 'monthly' ? 30 : 365,
      });

      // Ödeme geçmişine ekle
      await addPaymentHistory(
        userId,
        'premium_$plan',
        plan == 'monthly' ? 99.99 : 999.99,
        null,
        transactionId,
      );

      print('✅ Premium plan satın alındı: $userId - $plan');
    } catch (e) {
      print('❌ Premium plan satın alma hatası: $e');
      rethrow;
    }
  }

  // Tek ilan satın alma
  Future<void> purchaseSingleAd(String userId, String adId, double amount, String transactionId) async {
    try {
      final now = DateTime.now();
      final userData = await getUserData(userId);

      final currentSingleAdCount = (userData?['singleAdCount'] as num?)?.toInt() ?? 0;
      final currentTotalSpent = (userData?['totalSpent'] as num?)?.toDouble() ?? 0.0;

      await _database.child('users').child(userId).update({
        'singleAdCount': currentSingleAdCount + 1,
        'totalSpent': currentTotalSpent + amount,
        'lastSingleAdPayment': now.toIso8601String(),
        'lastUpdated': now.toIso8601String(),
      });

      // Ödeme geçmişine ekle
      await addPaymentHistory(
        userId,
        'single_ad',
        amount,
        adId,
        transactionId,
      );

      print('✅ Tek ilan satın alındı: $userId - $adId - ₺$amount');
    } catch (e) {
      print('❌ Tek ilan satın alma hatası: $e');
      rethrow;
    }
  }

  // Kullanıcının adsCount'ını artır
  Future<void> incrementAdsCount(String userId) async {
    try {
      final userData = await getUserData(userId);
      final currentCount = (userData?['adsCount'] as num?)?.toInt() ?? 0;

      await _database.child('users').child(userId).update({
        'adsCount': currentCount + 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Ads count artırma hatası: $e');
    }
  }

  // Ödeme geçmişine ekle
  Future<void> addPaymentHistory(
      String userId,
      String type, // 'single_ad', 'premium_monthly', 'premium_yearly'
      double amount,
      String? adId,
      String transactionId,
      ) async {
    try {
      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
      await _database.child('users').child(userId).child('paymentHistory').child(paymentId).set({
        'type': type,
        'amount': amount,
        'adId': adId,
        'transactionId': transactionId,
        'date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'paymentId': paymentId,
      });
      print('💰 Ödeme geçmişine eklendi: $type - ₺$amount');
    } catch (e) {
      print('❌ Ödeme geçmişi ekleme hatası: $e');
    }
  }

  // Kullanıcının aktif aboneliği var mı?
  Future<bool> hasActiveSubscription(String userId) async {
    try {
      final userData = await getUserData(userId);
      if (userData == null) return false;

      final premiumExpiry = userData['premiumExpiry'];
      final isPremium = userData['isPremium'] ?? false;

      if (isPremium && premiumExpiry != null) {
        final expiryDate = DateTime.parse(premiumExpiry);
        return expiryDate.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      print('❌ Abonelik kontrol hatası: $e');
      return false;
    }
  }

  // Kullanıcının ilan yayınlama limiti kontrolü
  Future<bool> canPublishNewAd(String userId) async {
    try {
      // Premium kullanıcılar için limitsiz
      final canPublish = await canPublishAd(userId);
      if (canPublish) {
        return true;
      }

      // Normal kullanıcılar için son ödeme kontrolü
      final userData = await getUserData(userId);
      if (userData == null) return false;

      final lastPayment = userData['lastSingleAdPayment'];
      if (lastPayment != null) {
        final lastPaymentDate = DateTime.parse(lastPayment);
        final now = DateTime.now();

        // Son 24 saat içinde ödeme yapmış mı?
        return lastPaymentDate.isAfter(now.subtract(Duration(hours: 24)));
      }

      return false;
    } catch (e) {
      print('❌ İlan yayınlama limit kontrol hatası: $e');
      return false;
    }
  }

  // Kullanıcının ödeme geçmişini getir
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).child('paymentHistory').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> history = [];

        data.forEach((key, value) {
          history.add(Map<String, dynamic>.from(value as Map));
        });

        history.sort((a, b) => b['date'].compareTo(a['date']));
        return history;
      }
      return [];
    } catch (e) {
      print('❌ Ödeme geçmişi getirme hatası: $e');
      return [];
    }
  }

  // Aboneliği iptal et
  Future<void> cancelSubscription(String userId) async {
    try {
      await _database.child('users').child(userId).update({
        'isPremium': false,
        'premiumExpiry': null,
        'subscriptionStatus': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      print('✅ Abonelik iptal edildi: $userId');
    } catch (e) {
      print('❌ Abonelik iptal hatası: $e');
      throw e;
    }
  }

  // Kullanıcının istatistiklerini getir
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userData = await getUserData(userId);
      final paymentHistory = await getPaymentHistory(userId);

      if (userData == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      double totalSpent = 0.0;
      for (var payment in paymentHistory) {
        totalSpent += (payment['amount'] as num).toDouble();
      }

      return {
        'adsCount': (userData['adsCount'] as num?)?.toInt() ?? 0,
        'singleAdCount': (userData['singleAdCount'] as num?)?.toInt() ?? 0,
        'totalSpent': totalSpent,
        'isPremium': userData['isPremium'] ?? false,
        'premiumPlan': userData['premiumPlan'],
        'premiumExpiry': userData['premiumExpiry'],
        'subscriptionStatus': userData['subscriptionStatus'] ?? 'none',
        'paymentCount': paymentHistory.length,
        'lastPayment': paymentHistory.isNotEmpty ? paymentHistory.first['date'] : null,
      };
    } catch (e) {
      print('❌ Kullanıcı istatistikleri hatası: $e');
      rethrow;
    }
  }
}