import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/ad_model.dart';

class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // ✅ ANA İLAN KAYDETME METODU (TÜM İLANLAR İÇİN TEK METOD)
  Future<String> saveAd({
    required String animalName,
    required String animalType,
    required String animalGender,
    required String adType,
    required String title,
    required String description,
    required String city,
    required String district,
    String? animalBreed,
    String? animalAge,
    String? animalColor,
    double? price,
    String? phone,
    bool vaccinated = false,
    File? imageFile,
    Uint8List? imageBytes,
    required String userId,
  }) async {
    print('🚀 ============ İLAN KAYIT BAŞLADI ============');

    try {
      // 1. Kullanıcı kontrolü
      if (_currentUser == null) {
        throw Exception('Lütfen önce giriş yapın!');
      }

      // 2. İlan ID oluştur
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(1000);
      final adId = 'ad_${timestamp}_$random';
      print('🆔 İlan ID: $adId');
      print('👤 Kullanıcı: $userId');

      // 3. Oluşturulma tarihi
      final createdAt = DateTime.now();
      print('📅 Oluşturulma: $createdAt');

      // 4. RESİMİ BASE64'E ÇEVİR (varsa)
      String? base64Image;
      int? imageSize;

      if (imageFile != null) {
        print('🖼️ Resim dosyası Base64\'e çevriliyor...');
        try {
          final bytes = await imageFile.readAsBytes();
          imageSize = bytes.length;
          base64Image = base64Encode(bytes);
          print('✅ Resim Base64\'e çevrildi: ${base64Image.length} karakter, $imageSize bytes');
        } catch (e) {
          print('⚠️ Resim Base64 çevirme hatası: $e');
        }
      } else if (imageBytes != null) {
        print('🖼️ ImageBytes Base64\'e çevriliyor...');
        try {
          imageSize = imageBytes.length;
          base64Image = base64Encode(imageBytes);
          print('✅ ImageBytes Base64\'e çevrildi: ${base64Image.length} karakter, $imageSize bytes');
        } catch (e) {
          print('⚠️ ImageBytes Base64 çevirme hatası: $e');
        }
      } else {
        print('ℹ️ Yüklenecek resim yok');
      }

      // 5. İlan verisini hazırla
      final adData = {
        'id': adId,
        'userId': userId,
        'userEmail': _currentUser!.email ?? '',
        'userName': _currentUser!.displayName ?? 'Kullanıcı',
        'animalName': animalName,
        'animalType': animalType,
        'animalGender': animalGender,
        'animalBreed': animalBreed ?? '',
        'animalAge': animalAge ?? '',
        'animalColor': animalColor ?? '',
        'city': city,
        'district': district,
        'adType': adType,
        'title': title,
        'description': description,
        'imageBase64': base64Image,
        'hasImage': base64Image != null,
        'imageSize': imageSize ?? 0,
        'price': price ?? 0,
        'phone': phone ?? '',
        'vaccinated': vaccinated,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
        'status': 'active',
        'views': 0,
        'likes': 0,
        'isFree': (price ?? 0) <= 0,
      };

      print('📊 İlan verisi hazır:');
      print('   🐾 Hayvan: $animalName ($animalType)');
      print('   📍 Konum: $city / $district');
      print('   💰 Fiyat: ${price ?? 0} TL');

      // 6. FIREBASE REALTIME DATABASE'E YAZ
      print('🔥 Firebase Realtime Database\'e yazılıyor...');

      // Ana 'ads' yoluna yaz
      await _database.child('ads').child(adId).set(adData);
      print('✅ Kayıt: /ads/$adId');

      // Kullanıcının ilanlarına ekle
      await _database.child('users').child(userId).child('ads').child(adId).set({
        'adId': adId,
        'animalName': animalName,
        'animalType': animalType,
        'adType': adType,
        'hasImage': base64Image != null,
        'createdAt': createdAt.toIso8601String(),
        'city': city,
        'status': 'active',
      });
      print('✅ Kullanıcı ilanlarına eklendi');

      // Kullanıcı istatistiklerini güncelle
      await _updateUserTotalAds(userId);

      print('🎉 ============ İLAN BAŞARIYLA KAYDEDİLDİ ============');
      print('🎯 İlan ID: $adId');
      print('👤 Kullanıcı: $userId');
      print('🐾 Hayvan: $animalName');
      print('==================================================');

      return adId;

    } catch (e, stackTrace) {
      print('❌❌❌ İLAN KAYIT HATASI ❌❌❌');
      print('📛 Hata: $e');
      print('📛 Stack: $stackTrace');

      if (e is FirebaseException) {
        print('🔥 Firebase Hata Kodu: ${e.code}');
        print('🔥 Firebase Hata Mesajı: ${e.message}');
      }

      throw Exception('İlan kaydedilirken hata oluştu: $e');
    }
  }

  // ✅ KULLANICININ AKTİF İLAN SAYISINI GETİR
  Future<int> getUserActiveAdCount(String userId) async {
    try {
      print('📊 Kullanıcı aktif ilan sayısı kontrol ediliyor: $userId');

      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('ads')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        print('ℹ️ Kullanıcının hiç ilanı yok');
        return 0;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      int activeCount = 0;

      data.forEach((adId, adData) {
        try {
          final adMap = Map<String, dynamic>.from(adData as Map);
          final status = adMap['status'] ?? 'active';

          if (status == 'active') {
            activeCount++;
          }
        } catch (e) {
          print('⚠️ İlan kontrol hatası: $e');
        }
      });

      print('✅ Kullanıcının aktif ilan sayısı: $activeCount');
      return activeCount;

    } catch (e) {
      print('❌ Aktif ilan sayısı getirme hatası: $e');
      return 0;
    }
  }

  // ✅ KULLANICI TOPLAM İLAN SAYISINI GÜNCELLE
  Future<void> _updateUserTotalAds(String userId) async {
    try {
      final activeCount = await getUserActiveAdCount(userId);

      await _database.child('users').child(userId).update({
        'totalAds': activeCount,
        'lastAdUpdate': DateTime.now().toIso8601String(),
      });

      print('📊 Kullanıcı totalAds güncellendi: $activeCount');
    } catch (e) {
      print('❌ TotalAds güncelleme hatası: $e');
    }
  }

  // ✅ KULLANICI İLAN SAYISI GETİR
  Future<int> getUserAdCount(String userId) async {
    try {
      final totalAdsSnapshot = await _database.child('users').child(userId).child('totalAds').get();

      if (totalAdsSnapshot.exists && totalAdsSnapshot.value != null) {
        final count = (totalAdsSnapshot.value as int);
        print('📊 Database\'den totalAds getirildi: $count');
        return count;
      }

      final activeCount = await getUserActiveAdCount(userId);
      print('📊 Aktif ilanlar sayıldı: $activeCount');
      return activeCount;

    } catch (e) {
      print('⚠️ İlan sayısı getirme hatası: $e');
      return 0;
    }
  }

  // ✅ SON İLANLARI GETİR
  Future<List<Ad>> getRecentAds({int limit = 5}) async {
    try {
      final allAds = await getAllAds();
      return allAds.take(limit).toList();
    } catch (e) {
      print('⚠️ Son ilanları getirme hatası: $e');
      return [];
    }
  }

  // ✅ TÜM İLANLARI GETİR
  Future<List<Ad>> getAllAds() async {
    try {
      print('📋 Tüm ilanlar getiriliyor...');
      final snapshot = await _database.child('ads').get();

      if (snapshot.exists) {
        List<Ad> ads = [];
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          try {
            final adMap = Map<String, dynamic>.from(value);
            final ad = Ad.fromMap(adMap, key.toString());
            ads.add(ad);

          } catch (e) {
            print('⚠️ İlan parse hatası (key: $key): $e');
          }
        });

        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        print('✅ ${ads.length} adet ilan getirildi');
        return ads;
      }
      print('ℹ️ Hiç ilan bulunamadı');
      return [];
    } catch (e) {
      print('❌ İlan getirme hatası: $e');
      return [];
    }
  }

  // ✅ KULLANICI İLANLARINI GETİR
  Future<List<Ad>> getUserAds(String userId) async {
    try {
      final allAds = await getAllAds();

      final userAds = allAds.where((ad) {
        return ad.userId == userId && ad.status == 'active';
      }).toList();

      print('👤 ${userAds.length} adet kullanıcı ilanı');
      return userAds;
    } catch (e) {
      print('⚠️ Kullanıcı ilanları hatası: $e');
      return [];
    }
  }

  // ✅ İLAN DETAY GETİR
  Future<Ad?> getAdById(String adId) async {
    try {
      final snapshot = await _database.child('ads').child(adId).get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final ad = Ad.fromMap(data, adId);
        print('📄 İlan detayı: ${ad.animalName} - Status: ${ad.status}');
        return ad;
      }
      return null;
    } catch (e) {
      print('⚠️ İlan detay hatası: $e');
      return null;
    }
  }

  // ✅ İLAN GÜNCELLE
  Future<void> updateAd(String adId, Map<String, dynamic> updates) async {
    try {
      await _database.child('ads').child(adId).update({
        ...updates,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (updates.containsKey('status')) {
        final ad = await getAdById(adId);
        if (ad != null) {
          await _updateUserTotalAds(ad.userId);
        }
      }

      print('✅ İlan güncellendi: $adId');
    } catch (e) {
      print('❌ İlan güncelleme hatası: $e');
      throw e;
    }
  }

  // ✅ İLAN SİL (soft delete)
  Future<void> deleteAd(String adId) async {
    try {
      final ad = await getAdById(adId);

      if (ad != null) {
        await _database.child('ads').child(adId).update({
          'status': 'deleted',
          'updatedAt': DateTime.now().toIso8601String(),
        });

        await _database.child('users').child(ad.userId).child('ads').child(adId).remove();
        await _updateUserTotalAds(ad.userId);
      }

      print('✅ İlan silindi: $adId');
    } catch (e) {
      print('❌ İlan silme hatası: $e');
      throw e;
    }
  }

  // ✅ İLAN GÖRÜNTÜLENME SAYISINI ARTIR
  Future<void> incrementAdViews(String adId) async {
    try {
      final adRef = _database.child('ads').child(adId);
      final snapshot = await adRef.child('views').get();

      int currentViews = 0;
      if (snapshot.exists && snapshot.value != null) {
        currentViews = (snapshot.value as int);
      }

      await adRef.update({'views': currentViews + 1});
      print('👁️ Görüntülenme artırıldı: $adId -> ${currentViews + 1}');
    } catch (e) {
      print('⚠️ Görüntülenme artırma hatası: $e');
    }
  }

  // ✅ FİLTRE İLE İLAN GETİR
  Future<List<Ad>> getAdsWithFilters({
    String? animalType,
    String? adType,
    String? city,
    String? searchQuery,
  }) async {
    try {
      final allAds = await getAllAds();

      return allAds.where((ad) {
        if (ad.status != 'active') return false;

        bool matches = true;

        if (animalType != null && animalType.isNotEmpty) {
          matches = matches && ad.animalType == animalType;
        }

        if (adType != null && adType.isNotEmpty) {
          matches = matches && ad.adType == adType;
        }

        if (city != null && city.isNotEmpty) {
          matches = matches && ad.city == city;
        }

        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          matches = matches && (
              ad.animalName.toLowerCase().contains(query) ||
                  ad.description.toLowerCase().contains(query) ||
                  ad.title.toLowerCase().contains(query) ||
                  (ad.animalBreed ?? '').toLowerCase().contains(query) ||
                  ad.city.toLowerCase().contains(query) ||
                  ad.district.toLowerCase().contains(query)
          );
        }

        return matches;
      }).toList();
    } catch (e) {
      print('⚠️ Filtreli ilan getirme hatası: $e');
      return [];
    }
  }

  // ✅ ÇİFTLEŞTİRME İLANLARINI GETİR
  Future<List<Ad>> getMatingAds() async {
    try {
      print('🔍 Çiftleştirme ilanları getiriliyor...');
      final allAds = await getAllAds();

      final matingAds = allAds.where((ad) {
        return ad.adType == 'Çiftleştirme' && ad.status == 'active';
      }).toList();

      print('✅ ${matingAds.length} adet çiftleştirme ilanı bulundu');
      return matingAds;
    } catch (e) {
      print('⚠️ Çiftleştirme ilanları hatası: $e');
      return [];
    }
  }

  // ✅ SAHİPLENDİRME İLANLARINI GETİR
  Future<List<Ad>> getAdoptionAds() async {
    try {
      print('🔍 Sahiplendirme ilanları getiriliyor...');
      final allAds = await getAllAds();

      final adoptionAds = allAds.where((ad) {
        return ad.adType == 'Sahiplendirme' && ad.status == 'active';
      }).toList();

      print('✅ ${adoptionAds.length} adet sahiplendirme ilanı bulundu');
      return adoptionAds;
    } catch (e) {
      print('⚠️ Sahiplendirme ilanları hatası: $e');
      return [];
    }
  }

  // ✅ İLAN SİLİNDİĞİNDE ÇAĞIR
  Future<void> onAdDeleted(String userId) async {
    await _updateUserTotalAds(userId);
  }

  // ✅ İLAN EKLENDİĞİNDE ÇAĞIR
  Future<void> onAdCreated(String userId) async {
    await _updateUserTotalAds(userId);
  }
}