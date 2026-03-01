// pages/edit_ad_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ad_model.dart';
import '../services/ad_service.dart';

class EditAdPage extends StatefulWidget {
  final String adId;
  final Map<String, dynamic>? adData;

  const EditAdPage({
    Key? key,
    required this.adId,
    this.adData,
  }) : super(key: key);

  @override
  _EditAdPageState createState() => _EditAdPageState();
}

class _EditAdPageState extends State<EditAdPage> {
  final _formKey = GlobalKey<FormState>();
  final AdService _adService = AdService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final List<String> _animalTypes = [
    'Köpek', 'Kedi', 'Kuş', 'Balık', 'Hamster', 'Tavşan', 'Diğer'
  ];

  final List<String> _dogBreeds = [
    'Kangal', 'Golden Retriever', 'Labrador', 'Poodle', 'Chihuahua', 'Bulldog',
    'Siberian Husky', 'Beagle', 'Rottweiler', 'Doberman', 'German Shepherd',
    'Pitbull', 'Terrier', 'Corgi', 'Pomeranian', 'Diğer'
  ];

  final List<String> _catBreeds = [
    'British Shorthair', 'Persian', 'Siamese', 'Maine Coon', 'Sphynx',
    'Bengal', 'Scottish Fold', 'Ragdoll', 'Birman', 'Turkish Van', 'Diğer'
  ];

  final List<String> _genders = ['Erkek', 'Dişi'];
  final List<String> _ageOptions = [
    '0-6 ay', '6-12 ay', '1-2 yaş', '2-3 yaş', '3-5 yaş', '5-7 yaş', '7+ yaş'
  ];
  final List<String> _adTypes = ['Sahiplendirme', 'Çiftleştirme'];
  final List<String> _colorOptions = [
    'Siyah', 'Beyaz', 'Kahverengi', 'Sarı', 'Gri', 'Alacalı', 'Diğer'
  ];

  // Form değişkenleri
  String _selectedAnimalType = '';
  String _selectedGender = '';
  String _selectedAge = '';
  String _selectedAdType = 'Sahiplendirme';
  String _selectedColor = '';
  bool _isVaccinated = false;
  bool _isFree = true;
  bool _isPremium = false;
  double _price = 0;

  // Text controller'lar
  late TextEditingController _animalNameController;
  late TextEditingController _breedController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;

  // Resim değişkenleri
  XFile? _selectedImage;
  String? _currentImageBase64;
  bool _hasImage = false;
  int _imageSize = 0;

  // Durum değişkenleri
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    // Controller'ları başlat
    _animalNameController = TextEditingController();
    _breedController = TextEditingController();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _districtController = TextEditingController();

    // İlan verilerini yükle
    _loadAdData();
  }

  Future<void> _loadAdData() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      Ad? ad;

      // Eğer adData verildiyse onu kullan, yoksa Firebase'den çek
      if (widget.adData != null) {
        ad = Ad.fromMap(widget.adData!, widget.adId);
      } else {
        ad = await _adService.getAdById(widget.adId);
      }

      if (ad != null) {
        // Form alanlarını doldur
        _animalNameController.text = ad.animalName;
        _selectedAnimalType = ad.animalType;
        _selectedGender = ad.animalGender;
        _breedController.text = ad.animalBreed ?? '';
        _selectedAge = ad.animalAge ?? '';
        _selectedColor = ad.animalColor ?? '';
        _cityController.text = ad.city; // Şehir text input
        _districtController.text = ad.district; // İlçe text input
        _selectedAdType = ad.adType;
        _titleController.text = ad.title;
        _descriptionController.text = ad.description;
        _phoneController.text = ad.phone ?? '';
        _isVaccinated = ad.vaccinated;
        _isFree = ad.isFree;
        _isPremium = ad.isPremium;
        _price = ad.price ?? 0;

        // Resim bilgileri
        _currentImageBase64 = ad.imageBase64;
        _hasImage = ad.hasImage;
        _imageSize = ad.imageSize;
      }
    } catch (e) {
      print('İlan verileri yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İlan verileri yüklenirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // Resim seçme fonksiyonu
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });

      // Resmi Base64'e çevir
      await _convertImageToBase64(image);
    }
  }

  Future<void> _convertImageToBase64(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _currentImageBase64 = base64String;
        _hasImage = true;
        _imageSize = bytes.length;
      });

      print('Resim boyutu: ${bytes.length ~/ 1024} KB');
    } catch (e) {
      print('Resim Base64 çevirme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resim yüklenirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Telefon numarasını formatla
  String _formatPhoneNumber(String phone) {
    // Başında +90 varsa kaldır
    phone = phone.replaceAll(RegExp(r'^\+90'), '');
    // Boşlukları temizle
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    // 0 ile başlamıyorsa 0 ekle
    if (!phone.startsWith('0')) {
      phone = '0$phone';
    }
    return phone;
  }

  // Form gönderme fonksiyonu
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Telefon kontrolü
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Telefon numarası zorunludur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Şehir ve ilçe kontrolü
    if (_cityController.text.isEmpty || _districtController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şehir ve ilçe bilgisi zorunludur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Telefon numarasını formatla
      String formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
      print('📱 Formatlanmış telefon: $formattedPhone');

      // Güncellenmiş ilan oluştur
      final updatedAd = Ad(
        id: widget.adId,
        userId: _currentUser?.uid ?? 'anonymous',
        userEmail: _currentUser?.email ?? '',
        userName: _currentUser?.displayName ?? 'Kullanıcı',
        animalName: _animalNameController.text.trim(),
        animalType: _selectedAnimalType,
        animalGender: _selectedGender,
        animalBreed: _breedController.text.trim().isNotEmpty ? _breedController.text.trim() : null,
        animalAge: _selectedAge,
        animalColor: _selectedColor,
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        adType: _selectedAdType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: widget.adData?['imageUrl'],
        imageBase64: _currentImageBase64,
        hasImage: _hasImage,
        imageSize: _imageSize,
        createdAt: DateTime.parse(widget.adData?['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.now(),
        status: 'active',
        isPremium: _isPremium,
        views: widget.adData?['views'] ?? 0,
        likes: widget.adData?['likes'] ?? 0,
        price: _selectedAdType == 'Sahiplendirme' && !_isFree ? _price : null,
        phone: formattedPhone,
        vaccinated: _isVaccinated,
        isFree: _isFree || _selectedAdType == 'Çiftleştirme',
      );

      // Firebase'de güncelle
      await _adService.updateAd(updatedAd);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İlan başarıyla güncellendi'),
          backgroundColor: Colors.green,
        ),
      );

      // Profil sayfasına dön
      Navigator.pop(context, true);

    } catch (e) {
      print('İlan güncelleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İlan güncellenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Resim widget'ı
  Widget _buildImageWidget() {
    if (_currentImageBase64 != null && _currentImageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_currentImageBase64!);
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            ),
          ),
        );
      } catch (e) {
        return _buildPlaceholderImage();
      }
    } else if (_selectedImage != null) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_selectedImage!.path),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'Resim Seç',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animalNameController.dispose();
    _breedController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: Text('İlanı Düzenle'),
          backgroundColor: Colors.blue[800],
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('İlanı Düzenle'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isLoading ? null : _submitForm,
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
              // Başlık
              Center(
                child: Text(
                  'İlan Bilgilerini Düzenle',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Resim Yükleme
              Center(
                child: Column(
                  children: [
                    Text(
                      'Resim',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickImage,
                      child: _buildImageWidget(),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _hasImage
                          ? 'Resim yüklendi (${_imageSize ~/ 1024} KB)'
                          : 'Resim yüklemek için tıklayın',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Temel Bilgiler
              Text(
                'Temel Bilgiler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 10),

              // İlan Tipi
              DropdownButtonFormField<String>(
                value: _selectedAdType,
                decoration: InputDecoration(
                  labelText: 'İlan Tipi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _adTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdType = value!;
                    if (value == 'Çiftleştirme') {
                      _isFree = true;
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'İlan tipi seçiniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Hayvan Adı
              TextFormField(
                controller: _animalNameController,
                decoration: InputDecoration(
                  labelText: 'Hayvan Adı *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Hayvan adı giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Hayvan Türü
              DropdownButtonFormField<String>(
                value: _selectedAnimalType.isNotEmpty ? _selectedAnimalType : null,
                decoration: InputDecoration(
                  labelText: 'Hayvan Türü *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _animalTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAnimalType = value!;
                    _breedController.clear();
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Hayvan türü seçiniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Cinsiyet
              DropdownButtonFormField<String>(
                value: _selectedGender.isNotEmpty ? _selectedGender : null,
                decoration: InputDecoration(
                  labelText: 'Cinsiyet *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.transgender),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Cinsiyet seçiniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Yaş
              DropdownButtonFormField<String>(
                value: _selectedAge.isNotEmpty ? _selectedAge : null,
                decoration: InputDecoration(
                  labelText: 'Yaş',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                  hintText: 'Yaş aralığı seçin',
                ),
                items: _ageOptions.map((age) {
                  return DropdownMenuItem(
                    value: age,
                    child: Text(age),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAge = value!;
                  });
                },
              ),
              SizedBox(height: 10),

              // Renk
              DropdownButtonFormField<String>(
                value: _selectedColor.isNotEmpty ? _selectedColor : null,
                decoration: InputDecoration(
                  labelText: 'Renk',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.color_lens),
                ),
                items: _colorOptions.map((color) {
                  return DropdownMenuItem(
                    value: color,
                    child: Text(color),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedColor = value!;
                  });
                },
              ),
              SizedBox(height: 10),

              // Irk
              if (_selectedAnimalType == 'Köpek' || _selectedAnimalType == 'Kedi')
                TextFormField(
                  controller: _breedController,
                  decoration: InputDecoration(
                    labelText: 'Irk (Opsiyonel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.psychology),
                    hintText: _selectedAnimalType == 'Köpek'
                        ? 'Örn: Golden Retriever'
                        : 'Örn: British Shorthair',
                  ),
                ),
              if (_selectedAnimalType == 'Köpek' || _selectedAnimalType == 'Kedi')
                SizedBox(height: 10),

              // Aşı Durumu
              SwitchListTile(
                title: Text('Aşıları Tamamlandı'),
                subtitle: Text(_isVaccinated ? 'Evet' : 'Hayır'),
                value: _isVaccinated,
                onChanged: (value) {
                  setState(() {
                    _isVaccinated = value;
                  });
                },
                secondary: Icon(
                  Icons.medical_services,
                  color: _isVaccinated ? Colors.green : Colors.grey,
                ),
              ),

              Divider(),
              SizedBox(height: 10),

              // Konum Bilgileri
              Text(
                'Konum Bilgileri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 10),

              // Şehir - TEXT INPUT
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'Şehir *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                  hintText: 'Örn: İstanbul, Ankara, İzmir',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şehir giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // İlçe - TEXT INPUT
              TextFormField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: 'İlçe *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'Örn: Kadıköy, Çankaya, Bornova',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'İlçe giriniz';
                  }
                  return null;
                },
              ),

              Divider(),
              SizedBox(height: 10),

              // Fiyat Bilgileri (Sadece Sahiplendirme için)
              if (_selectedAdType == 'Sahiplendirme')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiyat Bilgileri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),

                    SwitchListTile(
                      title: Text('Ücretsiz Sahiplendirme'),
                      subtitle: Text(_isFree ? 'Ücretsiz' : 'Ücretli'),
                      value: _isFree,
                      onChanged: (value) {
                        setState(() {
                          _isFree = value;
                          if (value) {
                            _price = 0;
                          }
                        });
                      },
                      secondary: Icon(
                        Icons.money_off,
                        color: _isFree ? Colors.green : Colors.grey,
                      ),
                    ),

                    if (!_isFree)
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Fiyat (TL)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'TL',
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _price > 0 ? _price.toStringAsFixed(0) : '',
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) {
                            _price = parsed;
                          }
                        },
                        validator: !_isFree ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Fiyat giriniz';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Geçerli bir fiyat giriniz';
                          }
                          return null;
                        } : null,
                      ),

                    Divider(),
                    SizedBox(height: 10),
                  ],
                ),

              // İletişim Bilgileri
              Text(
                'İletişim Bilgileri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 10),

              // Telefon
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası * (örn: 5551234567)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Telefon numarası giriniz';
                  }
                  final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cleaned.length < 10) {
                    return 'Geçerli bir telefon numarası giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // İlan Başlığı
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'İlan Başlığı *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                  hintText: 'Örn: Sevecen Golden Retriever Sahiplendirilecek',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'İlan başlığı giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Açıklama *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'Hayvanınız hakkında detaylı bilgi verin...',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Açıklama giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Kaydet Butonu
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'İLANI GÜNCELLE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}