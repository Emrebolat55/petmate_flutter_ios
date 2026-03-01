// lib/businesses_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // BU SATIRI EKLE
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class BusinessesPage extends StatefulWidget {
  @override
  _BusinessesPageState createState() => _BusinessesPageState();
}

class _BusinessesPageState extends State<BusinessesPage> {
  GoogleMapController? _mapController;
  Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentLatLng;
  String _currentDistrict = 'Yükleniyor...';
  String _currentCity = 'Yükleniyor...';
  String _currentAddress = '';
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _loading = true;
  String _errorMessage = '';
  List<String> _selectedTypes = ['veteriner', 'petshop', 'barınak'];
  bool _hasRealData = false;
  bool _noBusinessesFound = false;

  List<Business> _allBusinesses = [];

  // OpenStreetMap Overpass API endpoint
  final String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  final double _searchRadius = 10000; // 10 km

  final Map<String, BusinessType> _businessTypes = {
    'veteriner': BusinessType(
      name: 'Veteriner',
      icon: Icons.local_hospital,
      color: Colors.red,
      markerColor: BitmapDescriptor.hueRed,
      osmTags: [
        {'amenity': 'veterinary'},
        {'shop': 'veterinary'},
      ],
    ),
    'petshop': BusinessType(
      name: 'Petshop',
      icon: Icons.shopping_cart,
      color: Colors.green,
      markerColor: BitmapDescriptor.hueGreen,
      osmTags: [
        {'shop': 'pet'},
        {'shop': 'animals'},
      ],
    ),
    'barınak': BusinessType(
      name: 'Hayvan Barınağı',
      icon: Icons.pets,
      color: Colors.blue,
      markerColor: BitmapDescriptor.hueBlue,
      osmTags: [
        {'amenity': 'animal_shelter'},
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _getCurrentLocation();
      if (_currentLatLng != null) {
        await _fetchOpenStreetMapPlaces();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Konum alınamadı: $e';
        _noBusinessesFound = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalıcı olarak reddedildi.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });

      await _getAddressFromLatLng(position.latitude, position.longitude);

    } catch (e) {
      setState(() {
        _currentLatLng = LatLng(41.0351, 28.9833); // İstanbul Taksim
        _currentCity = 'İstanbul';
        _currentDistrict = 'Beyoğlu';
        _currentAddress = 'Konum alınamadı';
        _errorMessage = 'Konum alınamadı, İstanbul Taksim gösteriliyor';
      });
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _currentDistrict = place.locality ?? place.subLocality ?? 'Bilinmiyor';
          _currentCity = place.administrativeArea ?? 'Bilinmiyor';
          _currentAddress = place.street ?? '';
        });
      }
    } catch (e) {
      print("Adres hatası: $e");
      // Hata durumunda basit bir adres göster
      setState(() {
        _currentDistrict = 'Konum';
        _currentCity = 'Bilinmiyor';
        _currentAddress = 'Koordinat: $lat, $lng';
      });
    }
  }

  Future<void> _fetchOpenStreetMapPlaces() async {
    if (_currentLatLng == null) return;

    setState(() {
      _errorMessage = 'Yakınınızdaki işletmeler aranıyor...';
      _hasRealData = false;
      _noBusinessesFound = false;
    });

    try {
      List<Business> allBusinesses = [];

      // Her işletme tipi için ayrı ayrı sorgu yap
      for (String type in _selectedTypes) {
        try {
          List<Business> businesses = await _fetchBusinessesByType(type);
          allBusinesses.addAll(businesses);
        } catch (e) {
          print('$type için sorgu hatası: $e');
        }

        // API'yi yormamak için küçük bekleme
        await Future.delayed(Duration(milliseconds: 300));
      }

      if (allBusinesses.isNotEmpty) {
        // Benzersiz işletmeler
        final uniqueBusinesses = _removeDuplicateBusinesses(allBusinesses);

        setState(() {
          _allBusinesses = uniqueBusinesses;
          _hasRealData = true;
          _noBusinessesFound = false;
          _errorMessage = '${uniqueBusinesses.length} işletme bulundu';
          _createMarkers();
        });
      } else {
        setState(() {
          _allBusinesses = [];
          _hasRealData = false;
          _noBusinessesFound = true;
          _errorMessage = 'Yakınınızda hiç işletme bulunamadı';
          _createMarkers();
        });
      }
    } catch (e) {
      print('OpenStreetMap hatası: $e');
      setState(() {
        _errorMessage = 'İşletmeler yüklenirken hata oluştu';
        _hasRealData = false;
        _noBusinessesFound = true;
      });
    }
  }

  Future<List<Business>> _fetchBusinessesByType(String type) async {
    if (!_businessTypes.containsKey(type)) return [];

    final businessType = _businessTypes[type]!;
    final lat = _currentLatLng!.latitude;
    final lng = _currentLatLng!.longitude;

    List<Business> businesses = [];

    // Her tag için ayrı ayrı sorgu yap
    for (var tag in businessType.osmTags) {
      try {
        final key = tag.keys.first;
        final value = tag.values.first;

        String query = '''
          [out:json][timeout:25];
          (
            node["$key"="$value"](around:${_searchRadius.toInt()},$lat,$lng);
            way["$key"="$value"](around:${_searchRadius.toInt()},$lat,$lng);
          );
          out body;
          >;
          out skel qt;
        ''';

        final response = await http.post(
          Uri.parse(_overpassUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'data': query},
        ).timeout(Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['elements'] != null && data['elements'].isNotEmpty) {
            for (var element in data['elements']) {
              Business? business = _parseOSMElement(element, type);
              if (business != null) {
                businesses.add(business);
              }
            }
          }
        }
      } catch (e) {
        print('$type - $tag sorgu hatası: $e');
        continue;
      }
    }

    return businesses;
  }

  Business? _parseOSMElement(Map<String, dynamic> element, String type) {
    try {
      Map<String, dynamic> tags = {};
      if (element['tags'] != null) {
        tags = Map<String, dynamic>.from(element['tags']);
      }

      // Koordinatları al
      double lat, lng;
      if (element['type'] == 'node') {
        lat = element['lat'].toDouble();
        lng = element['lon'].toDouble();
      } else if (element['type'] == 'way' && element['center'] != null) {
        lat = element['center']['lat'].toDouble();
        lng = element['center']['lon'].toDouble();
      } else if (element['lat'] != null && element['lon'] != null) {
        lat = element['lat'].toDouble();
        lng = element['lon'].toDouble();
      } else {
        return null;
      }

      // İsim kontrolü - isimsiz işletmeleri gösterme
      String? name = tags['name'] ?? tags['name:tr'] ?? tags['name:en'];
      if (name == null || name.isEmpty) {
        return null;
      }

      return Business(
        id: element['id'].toString(),
        name: name,
        latitude: lat,
        longitude: lng,
        type: type,
        address: _buildAddressFromTags(tags),
        phone: tags['phone'] ?? tags['contact:phone'] ?? '',
        website: tags['website'] ?? tags['contact:website'] ?? '',
        openingHours: tags['opening_hours'] ?? '',
        rating: 0.0,
        totalRatings: 0,
        priceLevel: 0,
        isOpenStreetMapData: true,
        osmTags: tags,
      );
    } catch (e) {
      print('Element parse hatası: $e');
      return null;
    }
  }

  String _buildAddressFromTags(Map<String, dynamic> tags) {
    List<String> addressParts = [];

    if (tags['addr:street'] != null) addressParts.add(tags['addr:street']);
    if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber']);
    if (tags['addr:city'] != null) addressParts.add(tags['addr:city']);

    if (addressParts.isEmpty && tags['addr:full'] != null) {
      return tags['addr:full'];
    }

    return addressParts.isNotEmpty ? addressParts.join(' ') : 'Adres bilgisi yok';
  }

  List<Business> _removeDuplicateBusinesses(List<Business> businesses) {
    final uniqueBusinesses = <Business>[];
    final seenIds = <String>{};

    for (var business in businesses) {
      if (!seenIds.contains(business.id)) {
        seenIds.add(business.id);
        uniqueBusinesses.add(business);
      }
    }

    return uniqueBusinesses;
  }

  void _createMarkers() {
    Set<Marker> newMarkers = {};
    Set<Circle> newCircles = {};

    if (_currentLatLng != null) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position: _currentLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Konumunuz'),
        ),
      );

      newCircles.add(
        Circle(
          circleId: CircleId('radius'),
          center: _currentLatLng!,
          radius: _searchRadius,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 1,
        ),
      );
    }

    // Sadece gerçek işletmeleri göster
    for (var business in _allBusinesses) {
      final businessType = _businessTypes[business.type] ?? _businessTypes.values.first;

      newMarkers.add(
        Marker(
          markerId: MarkerId(business.id),
          position: LatLng(business.latitude, business.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(businessType.markerColor),
          infoWindow: InfoWindow(
            title: business.name,
            snippet: businessType.name,
          ),
          onTap: () {
            _showBusinessDetails(business);
          },
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      _circles = newCircles;
    });
  }

  void _showBusinessDetails(Business business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(_businessTypes[business.type]!.icon,
                        color: _businessTypes[business.type]!.color),
                    SizedBox(width: 10),
                    Text(_businessTypes[business.type]!.name),
                  ],
                ),
                SizedBox(height: 15),
                if (business.address.isNotEmpty && business.address != 'Adres bilgisi yok')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Adres:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(business.address),
                    ],
                  ),
                if (business.phone.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Telefon:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 5),
                      InkWell(
                        onTap: () => _launchUrl('tel:${business.phone}'),
                        child: Text(
                          business.phone,
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                if (business.website.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.web, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Website:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 5),
                      InkWell(
                        onTap: () => _launchUrl(business.website.startsWith('http')
                            ? business.website
                            : 'https://${business.website}'),
                        child: Text(
                          business.website,
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                if (business.openingHours.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Çalışma Saatleri:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(business.openingHours),
                    ],
                  ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openInMaps(business.latitude, business.longitude);
                        },
                        icon: Icon(Icons.directions),
                        label: Text('Yol Tarifi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uygulama açılamadı: $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL açma hatası: $e')),
      );
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    String url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    await _launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hayvan İşletmeleri'),
        backgroundColor: Colors.indigo[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _errorMessage = '';
                _noBusinessesFound = false;
              });
              _initializeLocation();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? LatLng(41.0351, 28.9833),
              zoom: 13,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _controller.complete(controller);
            },
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasRealData
                      ? Colors.green[50]
                      : _noBusinessesFound
                      ? Colors.orange[50]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _hasRealData
                        ? Colors.green
                        : _noBusinessesFound
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasRealData
                          ? Icons.check_circle
                          : _noBusinessesFound
                          ? Icons.info
                          : Icons.warning,
                      color: _hasRealData
                          ? Colors.green
                          : _noBusinessesFound
                          ? Colors.orange
                          : Colors.grey,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage,
                            style: TextStyle(fontSize: 14),
                          ),
                          if (_noBusinessesFound)
                            Text(
                              'Lütfen başka bir konumda deneyin',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.indigo),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Konumunuz',
                                style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('$_currentDistrict, $_currentCity',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                      if (_hasRealData)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                '${_allBusinesses.length} işletme',
                                style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (_noBusinessesFound)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.location_off, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Yakınınızda hayvan işletmesi bulunamadı. Arama yarıçapını artırmak için filtreleri değiştirin.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _goToMyLocation,
            child: Icon(Icons.my_location),
            backgroundColor: Colors.blue,
            mini: true,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _showFilterDialog,
            child: Icon(Icons.filter_list),
            backgroundColor: Colors.indigo,
            mini: true,
          ),
          SizedBox(height: 10),
          if (_noBusinessesFound)
            FloatingActionButton(
              onPressed: _testAnotherCity,
              child: Icon(Icons.search),
              backgroundColor: Colors.orange,
              mini: true,
            ),
        ],
      ),
    );
  }

  void _goToMyLocation() {
    if (_currentLatLng != null && _mapController != null) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng!, 13));
    }
  }

  void _testAnotherCity() {
    // Test için farklı bir şehirde işletme arama
    final List<Map<String, dynamic>> cities = [
      {'name': 'İstanbul', 'lat': 41.0082, 'lng': 28.9784},
      {'name': 'Ankara', 'lat': 39.9334, 'lng': 32.8597},
      {'name': 'İzmir', 'lat': 38.4237, 'lng': 27.1428},
      {'name': 'Bursa', 'lat': 40.1825, 'lng': 29.0664},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Şehir Seç'),
          content: Container(
            height: 200,
            child: ListView.builder(
              itemCount: cities.length,
              itemBuilder: (context, index) {
                final city = cities[index];
                return ListTile(
                  leading: Icon(Icons.location_city),
                  title: Text(city['name'] as String),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _loading = true;
                      _currentLatLng = LatLng(city['lat'] as double, city['lng'] as double);
                      _currentCity = city['name'] as String;
                      _currentDistrict = 'Merkez';
                      _errorMessage = '${city['name']} aranıyor...';
                    });
                    _fetchOpenStreetMapPlaces();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('İşletme Türleri'),
              content: Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._businessTypes.keys.map((type) {
                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Icon(_businessTypes[type]!.icon,
                                  color: _businessTypes[type]!.color, size: 20),
                              SizedBox(width: 10),
                              Text(_businessTypes[type]!.name),
                            ],
                          ),
                          value: _selectedTypes.contains(type),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedTypes.add(type);
                              } else {
                                _selectedTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                      SizedBox(height: 10),
                      Text(
                        'Daha fazla işletme bulmak için tüm türleri seçin',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _loading = true;
                      _errorMessage = '';
                      _noBusinessesFound = false;
                    });
                    _fetchOpenStreetMapPlaces();
                  },
                  child: Text('Ara'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class BusinessType {
  final String name;
  final IconData icon;
  final Color color;
  final double markerColor;
  final List<Map<String, String>> osmTags;

  BusinessType({
    required this.name,
    required this.icon,
    required this.color,
    required this.markerColor,
    required this.osmTags,
  });
}

class Business {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String address;
  final String phone;
  final String website;
  final String openingHours;
  final double rating;
  final int totalRatings;
  final int priceLevel;
  final bool isOpenStreetMapData;
  final Map<String, dynamic> osmTags;

  Business({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.address,
    required this.phone,
    required this.website,
    required this.openingHours,
    required this.rating,
    required this.totalRatings,
    required this.priceLevel,
    required this.isOpenStreetMapData,
    required this.osmTags,
  });
}