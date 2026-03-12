import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:petmate_flutter/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/locale_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_ad_page.dart';
import 'profile_page.dart';
import 'ads_list_page.dart';
import 'mating_page.dart';
import 'adoption_page.dart';
import 'settings_page.dart';
import 'services/database_service.dart';
import 'models/ad_model.dart';
import 'businesses_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide Ad;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseService _dbService = DatabaseService();

  // Reklam Değişkenleri
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _adUnitId = 'ca-app-pub-4939596189180370/7344864164';

  // Filtre state'leri
  String _selectedAnimalType = '';
  String _selectedAdType = '';
  final TextEditingController _cityFilterController = TextEditingController();
  final TextEditingController _districtFilterController = TextEditingController();

  // Son ilanlar
  List<Ad> _recentAds = [];
  bool _loadingRecentAds = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadRecentAds();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _cityFilterController.dispose();
    _districtFilterController.dispose();
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
          print('Banner reklam yüklenemedi: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadRecentAds() async {
    if (!_refreshing) {
      setState(() => _loadingRecentAds = true);
    }

    try {
      final ads = await _dbService.getRecentAds(limit: 5);

      setState(() {
        _recentAds = ads;
        _loadingRecentAds = false;
        _refreshing = false;
      });

      print('${ads.length} adet son ilan yüklendi');
    } catch (e) {
      print('Son ilanları yükleme hatası: $e');
      setState(() {
        _loadingRecentAds = false;
        _refreshing = false;
      });
    }
  }

  void _performFilteredSearch() {
    final city = _cityFilterController.text.trim();
    final district = _districtFilterController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdsListPage(
          filterType: _selectedAdType,
          filterAnimal: _selectedAnimalType,
          filterCity: city,
          filterDistrict: district,
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedAnimalType = '';
      _selectedAdType = '';
      _cityFilterController.clear();
      _districtFilterController.clear();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _refreshing = true);
    await _loadRecentAds();
  }

  // İlan verme butonuna basıldığında
  void _handleCreateAd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateAdPage()),
    ).then((value) {
      // İlan oluşturulduysa yenile
      if (value == true) {
        _refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.pets, color: Colors.white),
            SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.appTitle, style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            )),
          ],
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: AppLocalizations.of(context)!.viewAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.blue[800],
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Kullanıcı Bilgisi
              Container(
                color: Colors.blue[50],
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProfilePage()),
                        ).then((value) {
                          // Profilden döndüğünde yenile
                          if (value == true) {
                            _refreshData();
                          }
                        });
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.person, color: Colors.blue[800], size: 28),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.welcome + ',', style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          )),
                          Text(
                            _currentUser?.displayName ?? _currentUser?.email?.split('@').first ?? AppLocalizations.of(context)!.guest,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.qr_code, color: Colors.blue[800], size: 24),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('QR Kod özelliği yakında eklenecek'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filtreleme Bölümü
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.filters, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[800],
                        )),
                      ],
                    ),
                    SizedBox(height: 15),

                    // Hayvan Cinsi Filtresi
                    Text(AppLocalizations.of(context)!.animalType, style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.dog),
                            selected: _selectedAnimalType == 'Köpek',
                            selectedColor: Colors.blue[100],
                            checkmarkColor: Colors.blue[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAnimalType = selected ? 'Köpek' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.cat),
                            selected: _selectedAnimalType == 'Kedi',
                            selectedColor: Colors.blue[100],
                            checkmarkColor: Colors.blue[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAnimalType = selected ? 'Kedi' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.bird),
                            selected: _selectedAnimalType == 'Kuş',
                            selectedColor: Colors.blue[100],
                            checkmarkColor: Colors.blue[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAnimalType = selected ? 'Kuş' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.other),
                            selected: _selectedAnimalType == 'Diğer',
                            selectedColor: Colors.blue[100],
                            checkmarkColor: Colors.blue[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAnimalType = selected ? 'Diğer' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.all),
                            selected: _selectedAnimalType == '',
                            selectedColor: Colors.grey[100],
                            checkmarkColor: Colors.grey[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAnimalType = '';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // İlan Tipi Filtresi
                    Text(AppLocalizations.of(context)!.adType, style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.mating),
                            selected: _selectedAdType == 'Çiftleştirme',
                            selectedColor: Colors.pink[100],
                            checkmarkColor: Colors.pink[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAdType = selected ? 'Çiftleştirme' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.adoption),
                            selected: _selectedAdType == 'Sahiplendirme',
                            selectedColor: Colors.green[100],
                            checkmarkColor: Colors.green[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAdType = selected ? 'Sahiplendirme' : '';
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.all),
                            selected: _selectedAdType == '',
                            selectedColor: Colors.grey[100],
                            checkmarkColor: Colors.grey[800],
                            onSelected: (selected) {
                              setState(() {
                                _selectedAdType = '';
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // İl / İlçe Filtresi
                    Text(AppLocalizations.of(context)!.filterByLocation, style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityFilterController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.city,
                              hintText: AppLocalizations.of(context)!.enterCity,
                              prefixIcon: Icon(Icons.location_city, color: Colors.blue[700], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _districtFilterController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.district,
                              hintText: AppLocalizations.of(context)!.enterDistrict,
                              prefixIcon: Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Filtre Butonları
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _performFilteredSearch,
                            icon: Icon(Icons.search, size: 18),
                            label: Text(AppLocalizations.of(context)!.filterAndShow),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _clearAllFilters,
                            icon: Icon(Icons.clear, size: 18),
                            label: Text(AppLocalizations.of(context)!.clearFilters),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[800],
                              side: BorderSide(color: Colors.blue[800]!),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Hızlı Erişim Butonları (MESAJLAR KALDIRILDI)
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.ads, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue[800],
                    )),
                    SizedBox(height: 15),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.8,
                      children: [
                        QuickAccessButton(
                          icon: Icons.add_circle,
                          label: AppLocalizations.of(context)!.createAd,
                          color: Colors.blue[800]!,
                          onTap: _handleCreateAd,
                        ),
                        QuickAccessButton(
                          icon: Icons.favorite,
                          label: AppLocalizations.of(context)!.mating,
                          color: Colors.pink[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MatingPage()),
                            );
                          },
                        ),
                        QuickAccessButton(
                          icon: Icons.home,
                          label: AppLocalizations.of(context)!.adoption,
                          color: Colors.green[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdoptionPage()),
                            );
                          },
                        ),
                        QuickAccessButton(
                          icon: Icons.list,
                          label: AppLocalizations.of(context)!.allAds,
                          color: Colors.orange[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdsListPage(
                                  filterType: '',
                                  filterAnimal: '',
                                ),
                              ),
                            );
                          },
                        ),
                        QuickAccessButton(
                          icon: Icons.person,
                          label: AppLocalizations.of(context)!.profile,
                          color: Colors.purple[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProfilePage()),
                            ).then((value) {
                              // Profilden döndüğünde yenile
                              if (value == true) {
                                _refreshData();
                              }
                            });
                          },
                        ),
                        QuickAccessButton(
                          icon: Icons.business,
                          label: AppLocalizations.of(context)!.businesses,
                          color: Colors.indigo[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => BusinessesPage()),
                            );
                          },
                        ),
                        QuickAccessButton(
                          icon: Icons.settings,
                          label: AppLocalizations.of(context)!.settings,
                          color: Colors.grey[700]!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SettingsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Son İlanlar
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.recentAds, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[800],
                        )),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.refresh, size: 18, color: Colors.blue[600]),
                              onPressed: _refreshData,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdsListPage(
                                      filterType: '',
                                      filterAnimal: '',
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(AppLocalizations.of(context)!.viewAll, style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    _buildRecentAdsSection(),
                  ],
                ),
              ),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateAd,
        backgroundColor: Colors.blue[800],
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
        tooltip: 'Hızlı İlan Ver',
        elevation: 4,
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

  Widget _buildRecentAdsSection() {
    if (_loadingRecentAds) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue[800]),
              SizedBox(height: 16),
              Text(
                'İlanlar yükleniyor...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentAds.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.pets, size: 60, color: Colors.grey[300]),
            SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.noAdsFound,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'İlk ilanı vererek başlayın',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleCreateAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(AppLocalizations.of(context)!.createAd),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentAds.map((ad) => _buildAdCard(ad)).toList(),
    );
  }

  Widget _buildAdCard(Ad ad) {
    Color typeColor = ad.adType == 'Çiftleştirme'
        ? Colors.pink[700]!
        : Colors.green[700]!;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showAdDetails(ad),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resim
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ad.hasImage && ad.imageBase64 != null && ad.imageBase64!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(ad.imageBase64!),
                    fit: BoxFit.cover,
                  ),
                )
                    : ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            ad.animalType == 'Kedi'
                                ? Icons.pets
                                : ad.animalType == 'Köpek'
                                ? Icons.pets
                                : Icons.emoji_nature,
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                )
                    : Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: Icon(
                      ad.animalType == 'Kedi'
                          ? Icons.pets
                          : ad.animalType == 'Köpek'
                          ? Icons.pets
                          : Icons.emoji_nature,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ad.animalName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: typeColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            ad.adType,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.pets, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          ad.animalType,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.transgender, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          ad.gender,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${ad.city} / ${ad.district}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 12, color: Colors.grey[400]),
                        SizedBox(width: 4),
                        Text(
                          '${ad.views} görüntülenme',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                        Spacer(),
                        Text(
                          _formatTimeAgo(ad.createdAt),
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'az önce';
    if (difference.inMinutes < 60) return '${difference.inMinutes}d önce';
    if (difference.inHours < 24) return '${difference.inHours}s önce';
    if (difference.inDays < 1) return 'bugün';
    if (difference.inDays < 7) return '${difference.inDays}g önce';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}h önce';
    return '${(difference.inDays / 30).floor()}a önce';
  }

  void _showAdDetails(Ad ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
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
                              child: ad.hasImage && ad.imageBase64 != null && ad.imageBase64!.isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.memory(
                                  base64Decode(ad.imageBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  ad.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.blue[800],
                                      ),
                                    );
                                  },
                                ),
                              )
                                  : Center(
                                child: Icon(
                                  Icons.pets,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // İlan bilgileri
                            _buildAdDetailsContent(ad),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık ve tip
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
              if (ad.age > 0) _buildDetailRow('Yaş', '${ad.age} ay'),
              if (ad.breed.isNotEmpty) _buildDetailRow('Irk', ad.breed),
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

        // İletişim
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
                'İletişim',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.blue[700]),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Telefon', style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      )),
                      Text(
                        ad.phoneNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email, color: Colors.blue[700]),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('E-posta', style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      )),
                      Text(
                        ad.userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
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
}

class QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}