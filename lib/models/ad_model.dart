import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:typed_data';

class Ad {
  String id;
  String userId;
  String userEmail;
  String userName;
  String animalName;
  String animalType;
  String animalGender;
  String? animalBreed;
  String? animalAge;
  String? animalColor;
  String city;
  String district;
  String adType;
  String title;
  String description;
  String? imageUrl;
  String? imageBase64;
  bool hasImage;
  int imageSize;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? expiryDate; // YENİ: İlan son kullanma tarihi
  String status;
  bool isPremium;
  int views;
  int likes;
  double? price;
  String? phone;
  bool vaccinated;
  bool isFree;

  // YENİ: Ödeme bilgileri
  String? paymentType; // 'single_ad', 'premium_monthly', 'premium_yearly'
  double? paymentAmount; // Ödeme miktarı
  DateTime? paymentDate; // Ödeme tarihi
  String? transactionId; // Google Play transaction ID

  Ad({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.animalName,
    required this.animalType,
    required this.animalGender,
    this.animalBreed,
    this.animalAge,
    this.animalColor,
    required this.city,
    required this.district,
    required this.adType,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imageBase64,
    this.hasImage = false,
    this.imageSize = 0,
    required this.createdAt,
    required this.updatedAt,
    this.expiryDate,
    this.status = 'active',
    this.isPremium = false,
    this.views = 0,
    this.likes = 0,
    this.price,
    this.phone,
    this.vaccinated = false,
    this.isFree = true,
    this.paymentType,
    this.paymentAmount,
    this.paymentDate,
    this.transactionId,
  });

  // ESKİ FIELD'LAR İÇİN GETTER'LAR
  String get gender => animalGender;
  String get breed => animalBreed ?? '';
  String get phoneNumber => phone ?? '';

  // YENİ GETTER'LAR
  DateTime get effectiveExpiryDate => expiryDate ?? createdAt.add(Duration(days: 30));
  bool get isExpired => effectiveExpiryDate.isBefore(DateTime.now());
  bool get isActive => status == 'active' && !isExpired;

  String get paymentInfo {
    if (paymentType == 'single_ad') return 'Tek İlan ₺${paymentAmount?.toStringAsFixed(2) ?? "0.00"}';
    if (paymentType == 'premium_monthly') return 'Premium Aylık';
    if (paymentType == 'premium_yearly') return 'Premium Yıllık';
    return paymentType ?? 'Bilinmiyor';
  }

  String get daysRemaining {
    final now = DateTime.now();
    final expiry = effectiveExpiryDate;
    if (expiry.isBefore(now)) return 'Süresi Dolmuş';

    final diff = expiry.difference(now);
    if (diff.inDays > 0) return '${diff.inDays} gün kaldı';
    if (diff.inHours > 0) return '${diff.inHours} saat kaldı';
    return '${diff.inMinutes} dakika kaldı';
  }

  int get age {
    if (animalAge != null) {
      final ageStr = animalAge!.toLowerCase();
      if (ageStr.contains('yaş')) {
        final match = RegExp(r'(\d+)').firstMatch(ageStr);
        if (match != null) return int.parse(match.group(1)!);
      } else if (ageStr.contains('ay')) {
        final match = RegExp(r'(\d+)').firstMatch(ageStr);
        if (match != null) return (int.parse(match.group(1)!) / 12).floor();
      }
    }
    return 0;
  }

  // BASE64'ten Image.memory için Uint8List oluştur
  Uint8List? get imageBytes {
    if (hasImage && imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        return base64Decode(imageBase64!);
      } catch (e) {
        print('❌ Base64 decode hatası: $e');
        return null;
      }
    }
    return null;
  }

  // JSON'a çevir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'animalName': animalName,
      'animalType': animalType,
      'animalGender': animalGender,
      'animalBreed': animalBreed,
      'animalAge': animalAge,
      'animalColor': animalColor,
      'city': city,
      'district': district,
      'adType': adType,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'hasImage': hasImage,
      'imageSize': imageSize,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'status': status,
      'isPremium': isPremium,
      'views': views,
      'likes': likes,
      'price': price,
      'phone': phone,
      'vaccinated': vaccinated,
      'isFree': isFree,
      'paymentType': paymentType,
      'paymentAmount': paymentAmount,
      'paymentDate': paymentDate?.toIso8601String(),
      'transactionId': transactionId,
    };
  }

  // JSON'dan oluştur
  factory Ad.fromMap(Map<String, dynamic> map, String id) {
    return Ad(
      id: id,
      userId: map['userId']?.toString() ?? '',
      userEmail: map['userEmail']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'Kullanıcı',
      animalName: map['animalName']?.toString() ?? '',
      animalType: map['animalType']?.toString() ?? '',
      animalGender: map['animalGender']?.toString() ?? map['gender']?.toString() ?? '',
      animalBreed: map['animalBreed']?.toString() ?? map['breed']?.toString() ?? '',
      animalAge: map['animalAge']?.toString(),
      animalColor: map['animalColor']?.toString(),
      city: map['city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      adType: map['adType']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      imageBase64: map['imageBase64']?.toString(),
      hasImage: map['hasImage'] == true || (map['imageBase64'] != null && map['imageBase64'].toString().isNotEmpty),
      imageSize: (map['imageSize'] is int) ? map['imageSize'] as int : 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : DateTime.now(),
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'].toString())
          : null,
      status: map['status']?.toString() ?? 'active',
      isPremium: map['isPremium'] == true,
      views: (map['views'] is int) ? map['views'] as int : 0,
      likes: (map['likes'] is int) ? map['likes'] as int : 0,
      price: (map['price'] != null) ? double.tryParse(map['price'].toString()) : null,
      phone: map['phone']?.toString() ?? map['phoneNumber']?.toString() ?? '',
      vaccinated: map['vaccinated'] == true,
      isFree: map['isFree'] ?? true,
      paymentType: map['paymentType']?.toString(),
      paymentAmount: (map['paymentAmount'] != null)
          ? double.tryParse(map['paymentAmount'].toString())
          : null,
      paymentDate: map['paymentDate'] != null
          ? DateTime.parse(map['paymentDate'].toString())
          : null,
      transactionId: map['transactionId']?.toString(),
    );
  }

  // JSON string'e çevir
  String toJson() => json.encode(toMap());

  // JSON string'den oluştur
  factory Ad.fromJson(String source) => Ad.fromMap(json.decode(source), '');

  // copyWith metodu
  Ad copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? animalName,
    String? animalType,
    String? animalGender,
    String? animalBreed,
    String? animalAge,
    String? animalColor,
    String? city,
    String? district,
    String? adType,
    String? title,
    String? description,
    String? imageUrl,
    String? imageBase64,
    bool? hasImage,
    int? imageSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiryDate,
    String? status,
    bool? isPremium,
    int? views,
    int? likes,
    double? price,
    String? phone,
    bool? vaccinated,
    bool? isFree,
    String? paymentType,
    double? paymentAmount,
    DateTime? paymentDate,
    String? transactionId,
  }) {
    return Ad(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      animalName: animalName ?? this.animalName,
      animalType: animalType ?? this.animalType,
      animalGender: animalGender ?? this.animalGender,
      animalBreed: animalBreed ?? this.animalBreed,
      animalAge: animalAge ?? this.animalAge,
      animalColor: animalColor ?? this.animalColor,
      city: city ?? this.city,
      district: district ?? this.district,
      adType: adType ?? this.adType,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      hasImage: hasImage ?? this.hasImage,
      imageSize: imageSize ?? this.imageSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      isPremium: isPremium ?? this.isPremium,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      price: price ?? this.price,
      phone: phone ?? this.phone,
      vaccinated: vaccinated ?? this.vaccinated,
      isFree: isFree ?? this.isFree,
      paymentType: paymentType ?? this.paymentType,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  // YENİ: İlanın süresini uzat
  Ad extendExpiry(int additionalDays) {
    final newExpiryDate = effectiveExpiryDate.add(Duration(days: additionalDays));
    return copyWith(expiryDate: newExpiryDate);
  }

  // YENİ: İlanın ödeme bilgilerini güncelle
  Ad updatePaymentInfo({
    required String paymentType,
    required double paymentAmount,
    String? transactionId,
  }) {
    return copyWith(
      paymentType: paymentType,
      paymentAmount: paymentAmount,
      paymentDate: DateTime.now(),
      transactionId: transactionId,
      isPremium: paymentType != 'single_ad',
    );
  }

  // YENİ: İlanın durumunu güncelle
  Ad updateStatus(String newStatus) {
    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  // YENİ: İlan premium mu?
  bool get isPaidAd => paymentType != null && paymentType!.isNotEmpty;

  // YENİ: İlan premium üyelikten mi?
  bool get isFromPremium => paymentType == 'premium_monthly' || paymentType == 'premium_yearly';

  // YENİ: İlan süresi ne kadar kaldı?
  Duration get remainingDuration {
    final now = DateTime.now();
    final expiry = effectiveExpiryDate;
    return expiry.difference(now);
  }

  // YENİ: İlanın bitmesine kaç gün kaldı?
  int get remainingDays => remainingDuration.inDays;

  // YENİ: İlan aktif ve ödenmiş mi?
  bool get isActiveAndPaid => isActive && isPaidAd;

  // YENİ: İlanın geçerlilik durumu
  String get validityStatus {
    if (!isActive) return 'Pasif';
    if (isExpired) return 'Süresi Dolmuş';
    if (remainingDays <= 7) return 'Sona Yaklaşıyor';
    return 'Aktif';
  }

  // YENİ: İlanın ödeme türüne göre renk
  Color get paymentTypeColor {
    switch (paymentType) {
      case 'single_ad':
        return Color(0xFF2196F3); // Mavi
      case 'premium_monthly':
        return Color(0xFF4CAF50); // Yeşil
      case 'premium_yearly':
        return Color(0xFFFF9800); // Turuncu
      default:
        return Color(0xFF9E9E9E); // Gri
    }
  }

  // YENİ: İlanın geçerlilik durumu rengi
  Color get validityColor {
    if (!isActive) return Color(0xFF9E9E9E); // Gri
    if (isExpired) return Color(0xFFF44336); // Kırmızı
    if (remainingDays <= 7) return Color(0xFFFF9800); // Turuncu
    return Color(0xFF4CAF50); // Yeşil
  }

  // YENİ: İlan premium kullanıcı tarafından mı yayınlandı?
  bool get isPremiumUserAd => isPremium;

  // YENİ: İlanın görüntülenme oranı (yüzde)
  double get viewPercentage {
    if (views <= 0) return 0.0;
    return (views / 100.0).clamp(0.0, 100.0);
  }

  // YENİ: İlanın oluşturulma tarihini formatla
  String get formattedCreatedAt {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  // YENİ: İlanın bitiş tarihini formatla
  String get formattedExpiryDate {
    if (expiryDate == null) return '30 gün';

    final now = DateTime.now();
    final difference = expiryDate!.difference(now);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} ay ${difference.inDays % 30} gün';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat';
    } else {
      return 'Son gün';
    }
  }

  // YENİ: İlanın fiyat bilgisini formatla
  String get formattedPrice {
    if (price == null || price == 0) return 'Ücretsiz';
    return '₺${price!.toStringAsFixed(2)}';
  }

  // YENİ: İlanın ödeme miktarını formatla
  String get formattedPaymentAmount {
    if (paymentAmount == null) return '';
    return '₺${paymentAmount!.toStringAsFixed(2)}';
  }

  // YENİ: İlanın özet bilgisi
  String get summary {
    return '$animalName - $animalType - $city, $district';
  }

  // YENİ: İlan arama için indeks
  String get searchIndex {
    return '${animalName.toLowerCase()} ${animalType.toLowerCase()} ${breed.toLowerCase()} ${city.toLowerCase()} ${district.toLowerCase()} ${title.toLowerCase()} ${description.toLowerCase()}'.trim();
  }

  // YENİ: İlanın premium özelliklerini kontrol et
  Map<String, dynamic> get premiumFeatures {
    return {
      'hasImage': hasImage,
      'isPremium': isPremium,
      'isFromPremium': isFromPremium,
      'paymentType': paymentType,
      'remainingDays': remainingDays,
      'isActive': isActive,
    };
  }

  // YENİ: İlanın durum ikonu
  IconData get statusIcon {
    if (!isActive) return Icons.block;
    if (isExpired) return Icons.timer_off;
    if (remainingDays <= 7) return Icons.timer;
    return Icons.check_circle;
  }

  // YENİ: İlanın durum açıklaması
  String get statusDescription {
    if (!isActive) return 'İlanınız pasif durumda';
    if (isExpired) return 'İlan süreniz doldu';
    if (remainingDays <= 7) return 'İlan süreniz az kaldı';
    return 'İlanınız aktif ve yayında';
  }
}