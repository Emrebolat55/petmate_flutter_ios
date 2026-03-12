import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // YENİ EKLENDİ
import 'package:google_mobile_ads/google_mobile_ads.dart' hide Ad;
import '../services/database_service.dart';
import '../models/ad_model.dart';

class AdsListPage extends StatefulWidget {
  final String filterType;
  final String filterAnimal;
  final String filterCity;
  final String filterDistrict;

  const AdsListPage({
    Key? key,
    required this.filterType,
    this.filterAnimal = '',
    this.filterCity = '',
    this.filterDistrict = '',
  }) : super(key: key);

  @override
  _AdsListPageState createState() => _AdsListPageState();
}

class _AdsListPageState extends State<AdsListPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Ad> _ads = [];
  List<Ad> _filteredAds = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';

  // Reklam Değişkenleri
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _adUnitId = 'ca-app-pub-4939596189180370/3397115958';

  @override
  void initState() {
    super.initState();
    _loadAds();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('List Page Banner reklam yüklenemedi: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadAds() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📥 İlanlar yükleniyor...');
      List<Ad> ads;

      if (widget.filterType.isNotEmpty) {
        if (widget.filterType == 'Çiftleştirme') {
          print('🔍 Çiftleştirme ilanları filtresi');
          ads = await _dbService.getMatingAds();
        } else if (widget.filterType == 'Sahiplendirme') {
          print('🔍 Sahiplendirme ilanları filtresi');
          ads = await _dbService.getAdoptionAds();
        } else {
          ads = await _dbService.getAllAds();
        }
      } else {
        print('🔍 Tüm ilanlar getiriliyor');
        ads = await _dbService.getAllAds();
      }

      print('📊 Toplam ${ads.length} ilan bulundu');

      // Animal filter uygula
      if (widget.filterAnimal.isNotEmpty) {
        ads = ads.where((ad) => ad.animalType == widget.filterAnimal).toList();
        print('🐕 ${widget.filterAnimal} filtresi: ${ads.length} ilan');
      }

      // Şehir filtresi uygula
      if (widget.filterCity.isNotEmpty) {
        ads = ads.where((ad) =>
          ad.city.toLowerCase().contains(widget.filterCity.toLowerCase())
        ).toList();
        print('🏙 Şehir filtresi (${widget.filterCity}): ${ads.length} ilan');
      }

      // İlçe filtresi uygula
      if (widget.filterDistrict.isNotEmpty) {
        ads = ads.where((ad) =>
          ad.district.toLowerCase().contains(widget.filterDistrict.toLowerCase())
        ).toList();
        print('📍 İlçe filtresi (${widget.filterDistrict}): ${ads.length} ilan');
      }

      setState(() {
        _ads = ads;
        _filteredAds = ads;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ İlan yükleme hatası: $e');
      setState(() {
        _error = 'İlanlar yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  void _filterAds(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAds = _ads;
      } else {
        _filteredAds = _ads.where((ad) {
          return ad.animalName.toLowerCase().contains(query.toLowerCase()) ||
              ad.description.toLowerCase().contains(query.toLowerCase()) ||
              ad.city.toLowerCase().contains(query.toLowerCase()) ||
              ad.district.toLowerCase().contains(query.toLowerCase()) ||
              (ad.animalBreed ?? '').toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // YENİ: Telefon arama fonksiyonu
  Future<void> _makePhoneCall(String phoneNumber) async {
    // Telefon numarasını temizle ve formatla
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    // Eğer 0 ile başlıyorsa +90 ekle
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '+90${cleanedPhone.substring(1)}';
    }

    // Eğer + ile başlamıyorsa + ekle
    if (!cleanedPhone.startsWith('+')) {
      cleanedPhone = '+$cleanedPhone';
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanedPhone,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Telefon arama başlatılamadı'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAppBarTitle() {
    String title = 'Tüm İlanlar';

    if (widget.filterType == 'Çiftleştirme') {
      title = 'Çiftleştirme İlanları';
    } else if (widget.filterType == 'Sahiplendirme') {
      title = 'Sahiplendirme İlanları';
    }

    if (widget.filterAnimal.isNotEmpty) {
      title += ' (${widget.filterAnimal})';
    }

    if (_searchQuery.isNotEmpty) {
      title += ' - "$_searchQuery" arama sonuçları';
    }

    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.blue[800]!,
        actions: [
          if (_ads.isNotEmpty)
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: _AdSearchDelegate(_ads, _filterAds),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Yenileme butonuna basıldı');
              _loadAds();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error, style: TextStyle(color: Colors.red)))
          : _filteredAds.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'İlan bulunamadı',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            if (_searchQuery.isNotEmpty)
              Text(
                '"$_searchQuery" için sonuç bulunamadı',
                style: TextStyle(color: Colors.grey[600]),
              )
            else if (widget.filterAnimal.isNotEmpty)
              Text(
                '${widget.filterAnimal} için ${widget.filterType.isNotEmpty ? widget.filterType.toLowerCase() : ''} ilan bulunmuyor',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Text(
                'İlk ilanı siz verin!',
                style: TextStyle(color: Colors.grey[600]),
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: Text('Filtreleri Temizle'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAds,
        child: Column(
          children: [
            // İlan sayısı
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredAds.length} ilan bulundu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    InkWell(
                      onTap: () => _filterAds(''),
                      child: Row(
                        children: [
                          Icon(Icons.close, size: 16, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Aramayı temizle',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // İlan listesi
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _filteredAds.length,
                itemBuilder: (context, index) {
                  final ad = _filteredAds[index];
                  return _buildAdCard(ad);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? SafeArea(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
    );
  }

  Widget _buildAdCard(Ad ad) {
    Color typeColor = ad.adType == 'Çiftleştirme'
        ? Colors.pink[700]!
        : Colors.green[700]!;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showAdDetails(ad);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RESİM KISMI
            Container(
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: _buildImageWidget(ad),
              ),
            ),

            // İLAN DETAYLARI
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ad.animalName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: typeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          ad.adType,
                          style: TextStyle(
                            fontSize: 12,
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // TEMEL BİLGİLER
                  Row(
                    children: [
                      Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        ad.animalType,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.transgender, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        ad.gender,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        ad.animalAge ?? (ad.age > 0 ? '${ad.age} ay' : 'Yaş belirtilmemiş'),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // KONUM
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${ad.city} / ${ad.district}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // IRK VE AŞI
                  if ((ad.animalBreed ?? '').isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.psychology, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Irk: ${ad.animalBreed}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),

                  if (ad.vaccinated)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.medical_services, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Aşıları tamamlandı',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),

                  // FİYAT
                  if (ad.adType == 'Sahiplendirme' && ad.price != null && ad.price! > 0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.amber[700]),
                          SizedBox(width: 4),
                          Text(
                            '${ad.price!.toStringAsFixed(0)} TL',
                            style: TextStyle(
                              color: Colors.amber[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // AÇIKLAMA
                  SizedBox(height: 12),
                  Text(
                    ad.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),

                  SizedBox(height: 12),

                  // İSTATİSTİKLER
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        '${ad.views} görüntülenme',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Spacer(),
                      Icon(Icons.favorite, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        '${ad.likes} beğeni',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Spacer(),
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        _formatDate(ad.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // İLETİŞİM - DÜZENLENDİ
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'İletişim',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                ad.phoneNumber,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                ad.userEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ARA BUTONU
                        IconButton(
                          icon: Icon(Icons.phone_outlined, color: Colors.green),
                          onPressed: () {
                            _makePhoneCall(ad.phoneNumber);
                          },
                          tooltip: 'Ara',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Bugün';
    if (difference.inDays == 1) return 'Dün';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} hafta önce';
    return '${(difference.inDays / 30).floor()} ay önce';
  }

  Widget _buildImageWidget(Ad ad) {
    try {
      if (ad.hasImage && ad.imageBase64 != null && ad.imageBase64!.isNotEmpty) {
        String cleanBase64 = ad.imageBase64!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s'), '');

        try {
          final bytes = base64Decode(cleanBase64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderImage();
            },
          );
        } catch (decodeError) {
          return _buildPlaceholderImage();
        }
      }
      else if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty) {
        return Image.network(
          ad.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
        );
      }
      else {
        return _buildPlaceholderImage();
      }
    } catch (e) {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8),
            Text(
              'Resim Yok',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yardımcı fonksiyon
  int min(int a, int b) => a < b ? a : b;

  void _showAdDetails(Ad ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Sürükleme çubuğu
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // İçerik
                _buildAdDetailsContent(ad),
              ],
            ),
          ),
        );
      },
    );

    // Görüntülenme sayısını artır
    _dbService.incrementAdViews(ad.id);
  }

  Widget _buildAdDetailsContent(Ad ad) {
    Color typeColor = ad.adType == 'Çiftleştirme'
        ? Colors.pink[700]!
        : Colors.green[700]!;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resim
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[100],
            ),
            child: _buildDetailImage(ad),
          ),

          SizedBox(height: 20),

          // Başlık
          Row(
            children: [
              Expanded(
                child: Text(
                  ad.animalName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: typeColor),
                ),
                child: Text(
                  ad.adType,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // İstatistikler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.remove_red_eye, '${ad.views}', 'Görüntülenme'),
              _buildStatItem(Icons.favorite, '${ad.likes}', 'Beğeni'),
              _buildStatItem(Icons.calendar_today, _formatDate(ad.createdAt), 'Yayınlanma'),
            ],
          ),

          SizedBox(height: 20),

          // Detaylar
          _buildAdDetailsSection(ad),
        ],
      ),
    );
  }

  Widget _buildDetailImage(Ad ad) {
    try {
      if (ad.hasImage && ad.imageBase64 != null && ad.imageBase64!.isNotEmpty) {
        String cleanBase64 = ad.imageBase64!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s'), '');

        try {
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 250,
              errorBuilder: (context, error, stackTrace) {
                return _buildDetailPlaceholder();
              },
            ),
          );
        } catch (e) {
          return _buildDetailPlaceholder();
        }
      }
      return _buildDetailPlaceholder();
    } catch (e) {
      return _buildDetailPlaceholder();
    }
  }

  Widget _buildDetailPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 10),
          Text(
            'Resim Yok',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700]),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAdDetailsSection(Ad ad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Temel bilgiler
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildDetailRow('Hayvan Türü', ad.animalType),
              _buildDetailRow('Cinsiyet', ad.gender),
              if (ad.animalAge != null || ad.age > 0)
                _buildDetailRow('Yaş', ad.animalAge ?? '${ad.age} ay'),
              if ((ad.animalBreed ?? '').isNotEmpty)
                _buildDetailRow('Irk', ad.animalBreed ?? ''),
              _buildDetailRow('Konum', '${ad.city} / ${ad.district}'),
              if (ad.vaccinated) _buildDetailRow('Aşı Durumu', 'Tamamlandı ✅'),
              if (ad.price != null && ad.price! > 0)
                _buildDetailRow('Fiyat', '${ad.price!.toStringAsFixed(0)} TL'),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Açıklama
        Text(
          'Açıklama',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            ad.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),

        SizedBox(height: 20),

        // İletişim - DÜZENLENDİ
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İletişim Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),
              _buildContactRow(Icons.phone, 'Telefon', ad.phoneNumber),
              SizedBox(height: 8),
              _buildContactRow(Icons.email, 'E-posta', ad.userEmail),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _makePhoneCall(ad.phoneNumber);
                      },
                      icon: Icon(Icons.phone),
                      label: Text('Ara'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Mesaj gönder
                      },
                      icon: Icon(Icons.message),
                      label: Text('Mesaj'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[700]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: label == 'Telefon' ? 16 : 14,
                  fontWeight: label == 'Telefon' ? FontWeight.bold : FontWeight.normal,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Arama delegate sınıfı
class _AdSearchDelegate extends SearchDelegate<String> {
  final List<Ad> ads;
  final Function(String) onSearch;

  _AdSearchDelegate(this.ads, this.onSearch);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = ads.where((ad) {
      return ad.animalName.toLowerCase().contains(query.toLowerCase()) ||
          ad.description.toLowerCase().contains(query.toLowerCase()) ||
          ad.city.toLowerCase().contains(query.toLowerCase()) ||
          ad.district.toLowerCase().contains(query.toLowerCase()) ||
          (ad.animalBreed ?? '').toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '"$query" için sonuç bulunamadı',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final ad = results[index];
        return ListTile(
          leading: _buildSearchListImage(ad),
          title: Text(ad.animalName),
          subtitle: Text('${ad.animalType} - ${ad.city}'),
          trailing: Chip(
            label: Text(ad.adType),
            backgroundColor: ad.adType == 'Çiftleştirme'
                ? Colors.pink[100]
                : Colors.green[100],
          ),
          onTap: () {
            close(context, '');
            onSearch(ad.animalName);
          },
        );
      },
    );
  }

  Widget _buildSearchListImage(Ad ad) {
    try {
      if (ad.hasImage && ad.imageBase64 != null && ad.imageBase64!.isNotEmpty) {
        String cleanBase64 = ad.imageBase64!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s'), '');

        try {
          final bytes = base64Decode(cleanBase64);
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: MemoryImage(bytes),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (e) {
          return CircleAvatar(child: Icon(Icons.pets));
        }
      }
      return CircleAvatar(child: Icon(Icons.pets));
    } catch (e) {
      return CircleAvatar(child: Icon(Icons.pets));
    }
  }
}