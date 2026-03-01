import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _locationEnabled = true;
  bool _autoLogin = true;

  String _selectedLanguage = 'Türkçe';
  final List<String> _languages = ['Türkçe', 'English', 'Deutsch', 'Français'];

  String _selectedDistance = '10 km';
  final List<String> _distances = ['5 km', '10 km', '25 km', '50 km', '100 km'];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _applyDarkMode();
  }

  void _applyDarkMode() {
    // Karanlık mod uygulama tema ayarı
    // Gerçek uygulamada ThemeProvider kullanılması önerilir
  }

  Future<void> _loadUserSettings() async {
    if (_currentUser != null) {
      try {
        final snapshot = await _database
            .child('users')
            .child(_currentUser!.uid)
            .child('settings')
            .get();

        if (snapshot.exists) {
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

          setState(() {
            _notificationsEnabled = data['notifications'] ?? true;
            _darkMode = data['darkMode'] ?? false;
            _locationEnabled = data['location'] ?? true;
            _autoLogin = data['autoLogin'] ?? true;
            _selectedLanguage = data['language'] ?? 'Türkçe';
            _selectedDistance = data['distance'] ?? '10 km';
          });
        }
      } catch (e) {
        print('Ayarlar yükleme hatası: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_currentUser != null) {
      try {
        await _database
            .child('users')
            .child(_currentUser!.uid)
            .child('settings')
            .update({
          'notifications': _notificationsEnabled,
          'darkMode': _darkMode,
          'location': _locationEnabled,
          'autoLogin': _autoLogin,
          'language': _selectedLanguage,
          'distance': _selectedDistance,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ayarlar kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ayarlar kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profili Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Ad Soyad',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'E-posta: ${_currentUser?.email ?? ''}',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _currentUser?.updateDisplayName(nameController.text);
                await _database
                    .child('users')
                    .child(_currentUser!.uid)
                    .update({
                  'name': nameController.text,
                  'updatedAt': DateTime.now().toIso8601String(),
                });

                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profil güncellendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Güncelleme hatası: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Şifre Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre',
                border: OutlineInputBorder(),
                hintText: 'En az 6 karakter',
              ),
              obscureText: true,
            ),
            SizedBox(height: 10),
            Text(
              'Şifreniz en az 6 karakter uzunluğunda olmalıdır.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Şifre en az 6 karakter olmalı'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _currentUser?.updatePassword(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Şifre başarıyla değiştirildi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                String message = 'Şifre değiştirme hatası';
                if (e.code == 'requires-recent-login') {
                  message = 'Lütfen tekrar giriş yapın';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    final TextEditingController controller = TextEditingController(
      text: _currentUser?.email ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('E-posta Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Yeni E-posta',
                border: OutlineInputBorder(),
                hintText: 'ornek@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            Text(
              'E-posta değişikliği için doğrulama e-postası gönderilecektir.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _currentUser?.verifyBeforeUpdateEmail(controller.text);
                await _database
                    .child('users')
                    .child(_currentUser!.uid)
                    .update({
                  'email': controller.text,
                  'updatedAt': DateTime.now().toIso8601String(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Doğrulama e-postası gönderildi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('E-posta değiştirme hatası: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hesabı Sil'),
        content: Text(
            'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Ekstra doğrulama
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Son Uyarı'),
                  content: Text(
                      'Tüm ilanlarınız, mesajlarınız ve verileriniz silinecektir. Devam etmek istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Hayır'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performAccountDeletion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text('Evet, Sil'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    try {
      // Önce Firebase Database'den kullanıcı verilerini sil
      await _database.child('users').child(_currentUser!.uid).remove();

      // Firebase Auth'dan kullanıcıyı sil
      await _currentUser?.delete();

      // Başarılı silme sonrası anasayfaya yönlendir
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hesabınız başarıyla silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Hesap silme hatası';
      if (e.code == 'requires-recent-login') {
        message = 'Lütfen tekrar giriş yapıp tekrar deneyin';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$message: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hesap silinirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı açılamadı'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rateApp() async {
    // Play Store ve App Store bağlantıları
    const String appId = 'com.example.petmate';
    const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$appId';
    const String appStoreUrl = 'https://apps.apple.com/app/id$appId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Uygulamayı Değerlendir'),
        content: Text('Uygulamayı değerlendirmek için mağazaya yönlendirileceksiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchURL(playStoreUrl); // Varsayılan olarak Play Store
            },
            child: Text('Değerlendir'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Colors.blue),
              title: Text('E-posta ile Destek'),
              subtitle: Text('destek@petmate.com'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('mailto:destek@petmate.com');
              },
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green),
              title: Text('Telefon ile Destek'),
              subtitle: Text('+90 555 123 4567'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('tel:+905551234567');
              },
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.purple),
              title: Text('Canlı Destek'),
              subtitle: Text('Hafta içi 09:00-18:00'),
              onTap: () {
                Navigator.pop(context);
                // Canlı destek sayfasına yönlendir
              },
            ),
            ListTile(
              leading: Icon(Icons.question_answer, color: Colors.orange),
              title: Text('SSS'),
              subtitle: Text('Sıkça Sorulan Sorular'),
              onTap: () {
                Navigator.pop(context);
                // SSS sayfasına yönlendir
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gizlilik Politikası'),
        content: SingleChildScrollView(
          child: Text(
            '1. Kişisel Verilerin Toplanması\n'
                'Uygulamamız kullanıcı deneyimini iyileştirmek için sınırlı kişisel veri toplar.\n\n'
                '2. Veri Kullanımı\n'
                'Toplanan veriler sadece hizmet sunmak ve geliştirmek için kullanılır.\n\n'
                '3. Veri Paylaşımı\n'
                'Kişisel verileriniz üçüncü taraflarla paylaşılmaz.\n\n'
                '4. Güvenlik\n'
                'Verileriniz güvenli bir şekilde saklanır.\n\n'
                '5. Haklarınız\n'
                'Verilerinizi görüntüleme, düzeltme ve silme hakkına sahipsiniz.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showTermsConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanım Koşulları'),
        content: SingleChildScrollView(
          child: Text(
            '1. Kullanım Şartları\n'
                'Bu uygulamayı kullanarak aşağıdaki şartları kabul etmiş sayılırsınız.\n\n'
                '2. Hesap Sorumluluğu\n'
                'Hesabınızın güvenliğinden siz sorumlusunuz.\n\n'
                '3. İçerik Kuralları\n'
                'Uygunsuz içerik paylaşmak yasaktır.\n\n'
                '4. Hizmet Kesintileri\n'
                'Teknik nedenlerle hizmet kesintileri olabilir.\n\n'
                '5. Değişiklikler\n'
                'Koşullar zaman zaman güncellenebilir.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ayarlar'),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Ayarları Kaydet',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Kullanıcı Bilgisi
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, color: Colors.blue[800]),
              ),
              title: Text(
                _currentUser?.displayName ?? _currentUser?.email?.split('@').first ?? 'Kullanıcı',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_currentUser?.email ?? ''),
              trailing: Icon(Icons.edit),
              onTap: _updateProfile,
            ),
          ),
          SizedBox(height: 20),

          // Genel Ayarlar
          Text('Genel Ayarlar', style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          )),
          SizedBox(height: 10),

          _buildSettingSwitch(
            title: 'Bildirimler',
            subtitle: 'İlan bildirimlerini al',
            value: _notificationsEnabled,
            icon: Icons.notifications,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
          ),

          _buildSettingSwitch(
            title: 'Karanlık Mod',
            subtitle: 'Karanlık tema kullan',
            value: _darkMode,
            icon: Icons.dark_mode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              // Gerçek uygulamada burada ThemeProvider üzerinden tema değişimi yapılır
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tema değişikliği uygulamayı yeniden başlatınca aktif olacak'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          _buildSettingSwitch(
            title: 'Konum Servisi',
            subtitle: 'Konumunuzu kullan',
            value: _locationEnabled,
            icon: Icons.location_on,
            onChanged: (value) {
              setState(() => _locationEnabled = value);
              if (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Konum servisi aktif edildi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),

          _buildSettingSwitch(
            title: 'Otomatik Giriş',
            subtitle: 'Uygulamaya otomatik giriş yap',
            value: _autoLogin,
            icon: Icons.login,
            onChanged: (value) {
              setState(() => _autoLogin = value);
            },
          ),

          // Dil Ayarları
          SizedBox(height: 20),
          Text('Dil ve Bölge', style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          )),
          SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: Icon(Icons.language, color: Colors.blue),
              title: Text('Uygulama Dili'),
              subtitle: Text(_selectedLanguage),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                onChanged: (value) {
                  setState(() => _selectedLanguage = value!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dil değişikliği uygulamayı yeniden başlatınca aktif olacak'),
                    ),
                  );
                },
                items: _languages.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language),
                  );
                }).toList(),
              ),
            ),
          ),

          // Konum Ayarları
          SizedBox(height: 20),
          Text('Konum Ayarları', style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          )),
          SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: Icon(Icons.place, color: Colors.green),
              title: Text('Görüntüleme Mesafesi'),
              subtitle: Text('İlanları göster'),
              trailing: DropdownButton<String>(
                value: _selectedDistance,
                onChanged: (value) {
                  setState(() => _selectedDistance = value!);
                },
                items: _distances.map((distance) {
                  return DropdownMenuItem(
                    value: distance,
                    child: Text(distance),
                  );
                }).toList(),
              ),
            ),
          ),

          // Hesap Ayarları
          SizedBox(height: 20),
          Text('Hesap Ayarları', style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          )),
          SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.lock, color: Colors.orange),
                  title: Text('Şifre Değiştir'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.email, color: Colors.blue),
                  title: Text('E-posta Değiştir'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _changeEmail,
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Hesabı Sil'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),

          // Hakkında
          SizedBox(height: 20),
          Text('Hakkında', style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          )),
          SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: Colors.grey),
                  title: Text('Sürüm'),
                  subtitle: Text('1.0.0'),
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.description, color: Colors.grey),
                  title: Text('Gizlilik Politikası'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _showPrivacyPolicy,
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.description, color: Colors.grey),
                  title: Text('Kullanım Koşulları'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _showTermsConditions,
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.help, color: Colors.grey),
                  title: Text('Yardım ve Destek'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _showHelpSupport,
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.star, color: Colors.yellow),
                  title: Text('Uygulamayı Değerlendir'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _rateApp,
                ),
              ],
            ),
          ),

          // Çıkış Yap
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Çıkış Yap'),
                    content: Text('Çıkış yapmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('İptal'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/', (route) => false);
                        },
                        child: Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.logout),
              label: Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Versiyon
          Center(
            child: Text(
              'PetMate v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: Colors.blue),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}