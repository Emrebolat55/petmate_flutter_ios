import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/database_service.dart';
import 'package:petmate_flutter/l10n/generated/app_localizations.dart';

class CreateAdPage extends StatefulWidget {
  @override
  _CreateAdPageState createState() => _CreateAdPageState();
}

class _CreateAdPageState extends State<CreateAdPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Form controllers
  final TextEditingController _animalNameController = TextEditingController();
  final TextEditingController _animalBreedController = TextEditingController();
  final TextEditingController _animalAgeController = TextEditingController();
  final TextEditingController _animalColorController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // Seçimler
  String? _selectedAnimalType;
  String? _selectedGender;
  String? _selectedAdType;
  bool _vaccinated = false;

  // Resimler
  File? _selectedImageFile;
  Uint8List? _imageBytes;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Reklam Değişkenleri
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _adUnitId = 'ca-app-pub-4939596189180370/7319719528';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _animalNameController.dispose();
    _animalBreedController.dispose();
    _animalAgeController.dispose();
    _animalColorController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
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
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _selectedImageFile = file;
            _imageBytes = bytes;
          });
          _showMessage('✅ ${AppLocalizations.of(context)!.imageSelected}', Colors.green);
        }
      }
    } catch (e) {
      _showMessage(AppLocalizations.of(context)!.imageError, Colors.red);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _selectedImageFile = file;
            _imageBytes = bytes;
          });
          _showMessage('✅ ${AppLocalizations.of(context)!.photoTaken}', Colors.green);
        }
      }
    } catch (e) {
      _showMessage(AppLocalizations.of(context)!.cameraError, Colors.red);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _imageBytes = null;
    });
    _showMessage(AppLocalizations.of(context)!.imageRemoved, Colors.blue);
  }

  String _formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    if (!phone.startsWith('0')) {
      phone = '0$phone';
    }
    return phone;
  }

  Future<void> _checkPremiumAndSaveAd() async {
    final loc = AppLocalizations.of(context)!;

    if (_currentUser == null) {
      _showMessage(loc.pleaseLogin, Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAnimalType == null || _selectedGender == null || _selectedAdType == null) {
      _showMessage(loc.pleaseSelectAll, Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();

      if (customerInfo.entitlements.all["premium"] != null &&
          customerInfo.entitlements.all["premium"]!.isActive) {
        await _performSaveAd();
      } else {
        setState(() => _isLoading = false);
        PaywallResult result = await RevenueCatUI.presentPaywallIfNeeded('premium');

        if (result == PaywallResult.purchased || result == PaywallResult.restored) {
          setState(() => _isLoading = true);
          await _performSaveAd();
        } else {
          _showMessage(loc.premiumRequired, Colors.blue);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${AppLocalizations.of(context)!.paymentError}: $e';
      });
      _showMessage(AppLocalizations.of(context)!.subscriptionError, Colors.red);
    }
  }

  Future<void> _performSaveAd() async {
    final loc = AppLocalizations.of(context)!;
    try {
      String age = _animalAgeController.text.trim();
      String phone = _formatPhoneNumber(_phoneController.text.trim());

      final adId = await _dbService.saveAd(
        animalName: _animalNameController.text.trim(),
        animalType: _selectedAnimalType!,
        animalGender: _selectedGender!,
        adType: _selectedAdType!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        animalBreed: _animalBreedController.text.trim(),
        animalAge: age,
        animalColor: _animalColorController.text.trim(),
        price: double.tryParse(_priceController.text.trim()),
        phone: phone,
        vaccinated: _vaccinated,
        imageFile: _selectedImageFile,
        imageBytes: _imageBytes,
        userId: _currentUser!.uid,
      );

      print('✅ İlan kaydedildi! ID: $adId');

      setState(() {
        _successMessage = '✅ ${loc.adPublished}';
        _isLoading = false;
      });

      _showMessage('✅ ${loc.adPublished}', Colors.green);

      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.adSaveFailed;
        _isLoading = false;
      });
      _showMessage(AppLocalizations.of(context)!.errorOccurred, Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Dile göre seçenek listeleri
    final List<String> animalTypes = [loc.dog, loc.cat, loc.bird, loc.other];
    final List<String> genders = [loc.male, loc.female];
    final List<String> adTypes = [loc.adoption, loc.mating];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.createAdTitle),
        backgroundColor: Colors.blue[800],
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜST BANNER
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[900]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pets, color: Colors.yellow, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.premiumAd,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            loc.createAdSubtitle,
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // HATA/BAŞARI
              if (_errorMessage != null)
                _buildMessageCard(_errorMessage!, Colors.red, Icons.error),
              if (_successMessage != null)
                _buildMessageCard(_successMessage!, Colors.green, Icons.check_circle),

              // RESİM YÜKLEME
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📸 ${loc.addPhoto}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        loc.addPhotoHint,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 20),

                      if (_selectedImageFile != null && _imageBytes != null)
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue[300]!),
                                image: DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                TextButton.icon(
                                  onPressed: _removeImage,
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  label: Text(loc.remove, style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),

                      if (_imageBytes == null)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: Icon(Icons.photo_library),
                                label: Text(loc.gallery),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[100],
                                  foregroundColor: Colors.blue[800],
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: Icon(Icons.camera_alt),
                                label: Text(loc.camera),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[100],
                                  foregroundColor: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // HAYVAN BİLGİLERİ
              _buildSectionCard(
                title: '🐾 ${loc.animalInfo}',
                children: [
                  _buildTextField(
                    controller: _animalNameController,
                    label: '${loc.animalName} *',
                    icon: Icons.pets,
                    isRequired: true,
                  ),
                  _buildDropdown(
                    value: _selectedAnimalType,
                    label: '${loc.animalType} *',
                    icon: Icons.category,
                    items: animalTypes,
                    onChanged: (value) => setState(() => _selectedAnimalType = value),
                    isRequired: true,
                  ),
                  _buildDropdown(
                    value: _selectedGender,
                    label: '${loc.gender} *',
                    icon: Icons.transgender,
                    items: genders,
                    onChanged: (value) => setState(() => _selectedGender = value),
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _animalBreedController,
                    label: loc.breed,
                    icon: Icons.psychology,
                  ),
                  _buildTextField(
                    controller: _animalAgeController,
                    label: loc.age,
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _animalColorController,
                    label: loc.color,
                    icon: Icons.color_lens,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // İLAN BİLGİLERİ
              _buildSectionCard(
                title: '📋 ${loc.adInfo}',
                children: [
                  _buildDropdown(
                    value: _selectedAdType,
                    label: '${loc.adType} *',
                    icon: Icons.type_specimen,
                    items: adTypes,
                    onChanged: (value) => setState(() => _selectedAdType = value),
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _titleController,
                    label: '${loc.adTitle} *',
                    icon: Icons.title,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _descriptionController,
                    label: '${loc.description} *',
                    icon: Icons.description,
                    maxLines: 4,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _priceController,
                    label: '${loc.price} (TL)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // KONUM BİLGİLERİ
              _buildSectionCard(
                title: '📍 ${loc.locationInfo}',
                children: [
                  _buildTextField(
                    controller: _cityController,
                    label: '${loc.city} *',
                    icon: Icons.location_city,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _districtController,
                    label: '${loc.district} *',
                    icon: Icons.location_on,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: '${loc.phone} *',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // SAĞLIK BİLGİLERİ
              _buildSectionCard(
                title: '💉 ${loc.healthInfo}',
                children: [
                  SwitchListTile(
                    title: Text(loc.vaccinated),
                    value: _vaccinated,
                    onChanged: (value) => setState(() => _vaccinated = value),
                    activeColor: Colors.green,
                  ),
                ],
              ),

              SizedBox(height: 30),

              // KAYDET BUTONU
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkPremiumAndSaveAd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          loc.publishAdPremium,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              SizedBox(height: 20),

              // BİLGİ KARTI
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue[800]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc.premiumAdInfo,
                        style: TextStyle(color: Colors.blue[800], height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),
            ],
          ),
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

  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800])),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return loc.requiredField;
          }
          if (keyboardType == TextInputType.phone &&
              value != null &&
              value.isNotEmpty) {
            if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
              return loc.invalidPhone;
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: isRequired
            ? (value) => value == null ? loc.requiredField : null
            : null,
      ),
    );
  }
}