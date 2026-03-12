import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/ad_model.dart';
import 'edit_ad_page.dart';
import 'create_ad_page.dart';
import '../services/database_service.dart';
import 'package:petmate_flutter/l10n/generated/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseService _dbService = DatabaseService();

  List<Ad> _userAds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAds();
  }

  Future<void> _loadUserAds() async {
    try {
      if (_currentUser == null) {
        setState(() {
          _isLoading = false;
          _userAds = [];
        });
        return;
      }

      final ads = await _dbService.getUserAds(_currentUser!.uid);

      setState(() {
        _userAds = ads;
        _isLoading = false;
      });

      print('${ads.length} adet kullanıcı ilanı yüklendi');
    } catch (e) {
      print('İlan yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Kullanıcı istatistikleri
  Future<Map<String, dynamic>> _getUserStats() async {
    try {
      if (_currentUser == null) {
        return {'adsCount': 0};
      }

      return {
        'adsCount': _userAds.length,
      };
    } catch (e) {
      print('İstatistik hatası: $e');
      return {'adsCount': 0};
    }
  }

  Widget _buildAdImage(Ad ad) {
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
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            ),
          );
        } catch (e) {
          return _buildPlaceholderImage();
        }
      }
      return _buildPlaceholderImage();
    } catch (e) {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 50,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noImage,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    // İlanın süresi dolmuş mu kontrol et
    final bool isExpired = ad.expiryDate != null &&
        ad.expiryDate!.isBefore(DateTime.now());

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resim Kısmı
          Stack(
            children: [
              _buildAdImage(ad),
              if (isExpired)
                Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.expired.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // İlan tipi etiketi
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ad.adType == 'Sahiplendirme'
                            ? Colors.green[100]
                            : Colors.pink[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ad.adType == 'Sahiplendirme' ? AppLocalizations.of(context)!.adoption : AppLocalizations.of(context)!.mating,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ad.adType == 'Sahiplendirme'
                              ? Colors.green[800]
                              : Colors.pink[800],
                        ),
                      ),
                    ),

                    // Düzenleme ve Silme Butonları (sadece süresi dolmamışsa)
                    if (!isExpired)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            color: Colors.blue,
                            onPressed: () => _editAd(ad),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 20),
                            color: Colors.red,
                            onPressed: () => _deleteAd(ad),
                          ),
                        ],
                      ),
                  ],
                ),

                SizedBox(height: 10),
                Text(
                  ad.title.isNotEmpty ? ad.title : ad.animalName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '${ad.animalType} • ${ad.animalGender}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '${ad.city} / ${ad.district}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                // İlan süresi bilgisi
                if (ad.expiryDate != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          isExpired
                              ? '${AppLocalizations.of(context)!.expired}: ${ad.expiryDate!.day}.${ad.expiryDate!.month}.${ad.expiryDate!.year}'
                              : '${AppLocalizations.of(context)!.expiryDate}: ${ad.expiryDate!.day}.${ad.expiryDate!.month}.${ad.expiryDate!.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isExpired ? Colors.red : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 10),
                Text(
                  ad.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '${ad.views} ${AppLocalizations.of(context)!.views}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '${ad.likes} ${AppLocalizations.of(context)!.likes}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editAd(Ad ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAdPage(
          adId: ad.id,
          adData: ad.toMap(),
        ),
      ),
    ).then((value) {
      if (value == true) {
        _loadUserAds();
      }
    });
  }

  void _deleteAd(Ad ad) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteAd),
          content: Text('"${ad.title.isNotEmpty ? ad.title : ad.animalName}" ${AppLocalizations.of(context)!.deleteConfirm}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performDeleteAd(ad);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteAd(Ad ad) async {
    try {
      await _dbService.deleteAd(ad.id);
      await _loadUserAds();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.deleteSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.deleteError}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNewAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAdPage(),
      ),
    ).then((value) {
      if (value == true) {
        _loadUserAds();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profile),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getUserStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {'adsCount': 0};

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı Bilgileri
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue[100],
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppLocalizations.of(context)!.welcome},',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _currentUser?.displayName ?? _currentUser?.email?.split('@').first ?? AppLocalizations.of(context)!.guest,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.email, size: 16, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  _currentUser?.email ?? AppLocalizations.of(context)!.noEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // İstatistikler
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.stats,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatCard(
                            icon: Icons.list,
                            title: AppLocalizations.of(context)!.totalAds,
                            value: stats['adsCount'].toString(),
                            subtitle: _userAds.length.toString() + ' ${AppLocalizations.of(context)!.active}',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // İlanlarım Başlığı
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.myAds,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () async {
                              await _loadUserAds();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context)!.refreshAds),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            tooltip: AppLocalizations.of(context)!.refresh,
                          ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _handleNewAd,
                            icon: Icon(Icons.add),
                            label: Text(AppLocalizations.of(context)!.newAd),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // İlan Listesi
                _isLoading
                    ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
                    : _userAds.isEmpty
                    ? Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.list,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 16),
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
                        AppLocalizations.of(context)!.noAdsHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _handleNewAd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.createAd.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    : Column(
                  children: _userAds.map(_buildAdCard).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}