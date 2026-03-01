// lib/pages/premium_page.dart - GERÇEK SAYFA
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/payment_service.dart';

class PremiumPage extends StatefulWidget {
  @override
  _PremiumPageState createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final PaymentService _paymentService = PaymentService();

  String? _selectedPlan;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    try {
      await _paymentService.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Ödeme sistemi hazır değil: $e';
        _isInitialized = true;
      });
    }
  }

  Future<void> _purchasePremiumPlan() async {
    if (_selectedPlan == null) {
      _showMessage('Lütfen bir plan seçin');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final productId = _selectedPlan == 'monthly'
          ? 'premium_monthly'
          : 'premium_yearly';

      await _paymentService.purchaseProduct(productId);

      _showMessage(
          'Ödeme işlemi başlatıldı! Google Play üzerinden devam edin.',
          Colors.blue
      );

    } catch (e) {
      _showMessage('Ödeme başlatılamadı: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showMessage(String message, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Premium Üyelik'),
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    if (_hasError) {
      return _buildErrorScreen();
    }

    return _buildPremiumContent();
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Premium üyelikler yükleniyor...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Ödeme Sistemi Hatası',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Banner
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.star, size: 50, color: Colors.yellow),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREMIUM ÜYELİK',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Sınırsız ilan yayınlama ve premium özellikler',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),

          // Neden Premium?
          Text(
            'Premium Üye Olun, Farkı Yaşayın',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          SizedBox(height: 15),
          _buildFeature(Icons.check_circle, 'Sınırsız ilan yayınlama'),
          _buildFeature(Icons.visibility, 'Öncelikli görünürlük'),
          _buildFeature(Icons.photo_library, 'Sınırsız fotoğraf'),
          _buildFeature(Icons.support_agent, '7/24 öncelikli destek'),
          _buildFeature(Icons.analytics, 'Detaylı istatistikler'),
          _buildFeature(Icons.verified, 'Doğrulanmış hesap'),
          SizedBox(height: 30),

          // Plan Seçimi
          Center(
            child: Text(
              'PLANINIZI SEÇİN',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: 5),
          Center(
            child: Text(
              'Google Play ile güvenli ödeme',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 25),

          // Aylık Plan
          _buildPlanCard(
            isSelected: _selectedPlan == 'monthly',
            title: 'AYLIK PREMIUM',
            price: '₺99',
            period: 'aylık',
            badgeText: 'POPÜLER',
            badgeColor: Colors.blue,
            features: [
              'Sınırsız ilan yayınlama',
              'Öncelikli görünürlük',
              '7/24 öncelikli destek',
              'Doğrulanmış hesap rozeti',
              'Sınırsız fotoğraf yükleme',
              'Detaylı istatistikler',
            ],
            onTap: () => setState(() => _selectedPlan = 'monthly'),
          ),
          SizedBox(height: 20),

          // Yıllık Plan
          _buildPlanCard(
            isSelected: _selectedPlan == 'yearly',
            title: 'YILLIK PREMIUM',
            price: '₺999',
            period: 'yıllık',
            badgeText: '3 AY ÜCRETSİZ',
            badgeColor: Colors.green,
            features: [
              'Tüm aylık premium özellikler',
              '3 ay bedava (toplam 15 ay)',
              'Özel yıllık üye rozeti',
              'VIP destek ekibi',
              'İlan öncelik sıralaması',
              'VIP müşteri statüsü',
            ],
            onTap: () => setState(() => _selectedPlan = 'yearly'),
          ),
          SizedBox(height: 30),

          // Ödeme Butonu
          if (_isProcessing)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Ödeme işlemi başlatılıyor...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _selectedPlan == null ? null : _purchasePremiumPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPlan == 'monthly'
                      ? Colors.blue[800]
                      : Colors.green[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  _selectedPlan == null
                      ? 'BİR PLAN SEÇİN'
                      : '${_selectedPlan == 'monthly' ? '₺99' : '₺999'} ÖDEME YAP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          SizedBox(height: 20),

          // Güvenlik Bilgisi
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Güvenli Ödeme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '256-bit SSL şifreleme ile güvenli Google Play ödemesi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),

          // Bilgilendirme
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '• Abonelikler otomatik yenilenir\n'
                  '• İptal için: Google Play > Abonelikler\n'
                  '• 7 gün içinde memnun kalmazsanız iade',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[800],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required bool isSelected,
    required String title,
    required String price,
    required String period,
    required String badgeText,
    required Color badgeColor,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? badgeColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 15),

              // Başlık
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              SizedBox(height: 10),

              // Fiyat
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    '/$period',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Özellikler
              Column(
                children: features.map((feature) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
              SizedBox(height: 20),

              // Seçim İşareti
              if (isSelected)
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}