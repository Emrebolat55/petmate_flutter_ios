import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

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

  final List<String> _animalTypes = ['Köpek', 'Kedi', 'Kuş', 'Diğer'];
  final List<String> _genders = ['Erkek', 'Dişi'];
  final List<String> _adTypes = ['Sahiplendirme', 'Çiftleştirme'];

  @override
  void initState() {
    super.initState();
    print('🚀 CreateAdPage başlatıldı');
    print('👤 Kullanıcı ID: ${_currentUser?.uid ?? 'Giriş yapılmamış'}');
  }

  @override
  void dispose() {
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

  // RESİM SEÇ
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

          _showMessage('✅ Resim seçildi', Colors.green);
        }
      }
    } catch (e) {
      _showMessage('Resim seçilemedi', Colors.red);
    }
  }

  // KAMERADAN RESİM ÇEK
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

          _showMessage('✅ Fotoğraf çekildi', Colors.green);
        }
      }
    } catch (e) {
      _showMessage('Kamera hatası', Colors.red);
    }
  }

  // RESİM SİL
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _imageBytes = null;
    });
    _showMessage('Resim kaldırıldı', Colors.blue);
  }

  // Telefon formatı
  String _formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    if (!phone.startsWith('0')) {
      phone = '0$phone';
    }
    return phone;
  }

  // İLAN KAYDET - DÜZELTİLMİŞ VERSİYON
  Future<void> _saveAd() async {
    // Kullanıcı kontrolü
    if (_currentUser == null) {
      _showMessage('Lütfen giriş yapın', Colors.red);
      return;
    }

    // Form validasyonu
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Zorunlu alan kontrolü
    if (_selectedAnimalType == null ||
        _selectedGender == null ||
        _selectedAdType == null) {
      _showMessage('Lütfen tüm seçimleri yapın', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('📝 İlan kaydediliyor...');
      print('👤 UserID: ${_currentUser!.uid}');

      // Yaş değerini düzenle
      String age = _animalAgeController.text.trim();

      // Telefon numarasını formatla
      String phone = _formatPhoneNumber(_phoneController.text.trim());

      // İLANI KAYDET - userId PARAMETRESİ İLE BİRLİKTE!
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
        userId: _currentUser!.uid, // ← BURASI ÇOK ÖNEMLİ!
      );

      print('✅ İlan kaydedildi! ID: $adId');

      setState(() {
        _successMessage = '✅ İlanınız başarıyla yayınlandı!';
        _isLoading = false;
      });

      _showMessage('✅ İlanınız yayınlandı!', Colors.green);

      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      print('❌ Hata: $e');
      setState(() {
        _errorMessage = 'İlan kaydedilemedi. Lütfen tekrar deneyin.';
        _isLoading = false;
      });
      _showMessage('Hata oluştu', Colors.red);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Yeni İlan Oluştur'),
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
              // HOŞGELDİN MESAJI
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
                            'ÜCRETSİZ İLAN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hemen ilanını oluştur, platformda yerini al!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // HATA/BAŞARI MESAJLARI
              if (_errorMessage != null)
                _buildMessageCard(_errorMessage!, Colors.red, Icons.error),

              if (_successMessage != null)
                _buildMessageCard(_successMessage!, Colors.green, Icons.check_circle),

              // RESİM YÜKLEME KARTI
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📸 Resim Ekle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Resim eklemek ilanınızın daha çok görüntülenmesini sağlar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
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
                                  '${(_imageBytes!.length/1024).toStringAsFixed(1)} KB',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                TextButton.icon(
                                  onPressed: _removeImage,
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  label: Text('Kaldır', style: TextStyle(color: Colors.red)),
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
                                label: Text('Galeri'),
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
                                label: Text('Kamera'),
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

              // TEMEL BİLGİLER
              _buildSectionCard(
                title: '🐾 Hayvan Bilgileri',
                children: [
                  _buildTextField(
                    controller: _animalNameController,
                    label: 'Hayvanın Adı *',
                    icon: Icons.pets,
                    isRequired: true,
                  ),
                  _buildDropdown(
                    value: _selectedAnimalType,
                    label: 'Hayvan Türü *',
                    icon: Icons.category,
                    items: _animalTypes,
                    onChanged: (value) => setState(() => _selectedAnimalType = value),
                    isRequired: true,
                  ),
                  _buildDropdown(
                    value: _selectedGender,
                    label: 'Cinsiyet *',
                    icon: Icons.transgender,
                    items: _genders,
                    onChanged: (value) => setState(() => _selectedGender = value),
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _animalBreedController,
                    label: 'Irk',
                    icon: Icons.psychology,
                  ),
                  _buildTextField(
                    controller: _animalAgeController,
                    label: 'Yaş',
                    icon: Icons.cake,
                  ),
                  _buildTextField(
                    controller: _animalColorController,
                    label: 'Renk',
                    icon: Icons.color_lens,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // İLAN BİLGİLERİ
              _buildSectionCard(
                title: '📋 İlan Bilgileri',
                children: [
                  _buildDropdown(
                    value: _selectedAdType,
                    label: 'İlan Türü *',
                    icon: Icons.type_specimen,
                    items: _adTypes,
                    onChanged: (value) => setState(() => _selectedAdType = value),
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _titleController,
                    label: 'İlan Başlığı *',
                    icon: Icons.title,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Açıklama *',
                    icon: Icons.description,
                    maxLines: 4,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _priceController,
                    label: 'Fiyat (TL)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // KONUM BİLGİLERİ
              _buildSectionCard(
                title: '📍 Konum Bilgileri',
                children: [
                  _buildTextField(
                    controller: _cityController,
                    label: 'Şehir *',
                    icon: Icons.location_city,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _districtController,
                    label: 'İlçe *',
                    icon: Icons.location_on,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Telefon *',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // SAĞLIK BİLGİLERİ
              _buildSectionCard(
                title: '💉 Sağlık Bilgileri',
                children: [
                  SwitchListTile(
                    title: Text('Aşıları Tamamlandı'),
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
                  onPressed: _isLoading ? null : _saveAd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'İLANI ÜCRETSİZ YAYINLA',
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
                    Icon(Icons.info, color: Colors.blue[800]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '• İlanlar ücretsiz\n'
                            '• Telefon: 0 ile başlamalı\n'
                            '• Resim ekleyin\n'
                            '• Bilgiler doğru olmalı',
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
    );
  }

  // YARDIMCI WIDGETLAR
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
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            return 'Bu alan zorunlu';
          }
          if (keyboardType == TextInputType.phone && value != null && value.isNotEmpty) {
            if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
              return 'Geçerli telefon girin';
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
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        validator: isRequired ? (value) => value == null ? 'Bu alan zorunlu' : null : null,
      ),
    );
  }
}