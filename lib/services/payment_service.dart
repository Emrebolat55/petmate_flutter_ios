// lib/services/payment_service.dart - GERÇEK ÖDEME
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // 🔥 GERÇEK ÖDEME MOD
  bool _isInitialized = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Ürün ID'leri - Google Play Console'da aynı olacak
  static const String _monthlyProductId = 'premium_monthly';
  static const String _yearlyProductId = 'premium_yearly';

  Future<void> initialize() async {
    print('💰 PaymentService gerçek modda başlatılıyor');

    try {
      // 1. IAP kontrolü
      final isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) {
        throw Exception('Google Play satın alma kullanılamıyor');
      }

      // 2. Ürünleri yükle
      await _loadProducts();

      // 3. Satın alma dinleyicisi
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdate,
      );

      _isInitialized = true;
      print('✅ PaymentService başarıyla başlatıldı');

    } catch (e) {
      print('❌ PaymentService başlatma hatası: $e');
      rethrow;
    }
  }

  Future<void> _loadProducts() async {
    try {
      final productIds = {_monthlyProductId, _yearlyProductId};
      final response = await InAppPurchase.instance.queryProductDetails(productIds);

      if (response.error != null) {
        print('⚠️ Ürün yükleme hatası: ${response.error}');
        throw Exception('Ürünler yüklenemedi');
      }

      _products = response.productDetails;
      print('✅ ${_products.length} ürün yüklendi');

    } catch (e) {
      print('❌ Ürün yükleme hatası: $e');
      rethrow;
    }
  }

  Future<void> purchaseProduct(String productId) async {
    try {
      // Ürünü bul
      final product = _products.firstWhere(
            (p) => p.id == productId,
        orElse: () => throw Exception('Ürün bulunamadı: $productId'),
      );

      // Satın alma başlat
      final param = PurchaseParam(productDetails: product);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);

      print('✅ Satın alma işlemi başlatıldı: $productId');

    } catch (e) {
      print('❌ Satın alma hatası: $e');
      rethrow;
    }
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        await _activatePremium(purchaseDetails.productID);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _activatePremium(String productId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final now = DateTime.now();
      final expiryDate = productId == _monthlyProductId
          ? now.add(Duration(days: 30))
          : now.add(Duration(days: 365));

      final planName = productId == _monthlyProductId ? 'monthly' : 'yearly';

      await FirebaseDatabase.instance.ref('users/$userId').update({
        'isPremium': true,
        'premiumExpiry': expiryDate.toIso8601String(),
        'premiumPlan': planName,
        'premiumPurchaseDate': now.toIso8601String(),
      });

      print('✅ Premium aktif edildi: $planName');

    } catch (e) {
      print('❌ Premium aktif etme hatası: $e');
    }
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _subscription?.cancel();
  }
}