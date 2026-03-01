import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _silentFirebaseTest();
  }

  void _silentFirebaseTest() async {
    try {
      await _database.child('connection_test').set({
        'timestamp': DateTime.now().toString(),
      });
      await _database.child('connection_test').remove();
    } catch (e) {
      print('Firebase test (silent): $e');
    }
  }

  void _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Lütfen e-posta ve şifre girin');
      return;
    }

    if (_showRegister && (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty)) {
      _showError('Lütfen ad ve soyad girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential? userCredential;

      if (_showRegister) {
        // KAYIT OL
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        await userCredential.user?.updateDisplayName(fullName);

        if (userCredential.user != null) {
          // Kullanıcı profilini oluştur
          await _database.child('users/${userCredential.user!.uid}').set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'fullName': fullName,
            'email': _emailController.text.trim(),
            'createdAt': DateTime.now().toIso8601String(),
            'lastLogin': DateTime.now().toIso8601String(),
            'adsCount': 0,
          });
        }

        _showSuccess('Kayıt başarılı! Hoş geldin $fullName');
      } else {
        // GİRİŞ YAP
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userCredential.user != null) {
          // Son giriş zamanını güncelle
          await _database.child('users/${userCredential.user!.uid}/lastLogin').set(
            DateTime.now().toIso8601String(),
          );
        }
      }

      if (userCredential.user != null) {
        // Ana sayfaya yönlendir (premium parametresi olmadan)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      _showError(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(dynamic e) {
    String error = e.toString();

    if (error.contains('email-already-in-use')) {
      return 'Bu e-posta adresi zaten kullanımda';
    } else if (error.contains('weak-password')) {
      return 'Şifre en az 6 karakter olmalıdır';
    } else if (error.contains('invalid-email')) {
      return 'Geçersiz e-posta adresi';
    } else if (error.contains('user-not-found')) {
      return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
    } else if (error.contains('wrong-password')) {
      return 'Yanlış şifre';
    } else if (error.contains('network-request-failed')) {
      return 'İnternet bağlantınızı kontrol edin';
    } else if (error.contains('permission-denied')) {
      return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin';
    } else {
      return 'Bir hata oluştu. Lütfen tekrar deneyin';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Grey tonları için sabit renkler
    final Color grey300 = Color(0xFFE0E0E0);
    final Color grey600 = Color(0xFF757575);
    final Color blue800 = Color(0xFF1565C0);
    final Color blue100 = Color(0xFFBBDEFB);

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),

                // Logo ve Başlık
                Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: blue100,
                      child: Icon(
                        Icons.pets,
                        size: 60,
                        color: blue800,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'PetMate',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: blue800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _showRegister ? 'Yeni Hesap Oluştur' : 'Hesabınıza Giriş Yapın',
                      style: TextStyle(
                        fontSize: 16,
                        color: grey600,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 40),

                // Ad ve Soyad Alanları (Sadece Kayıt için)
                if (_showRegister) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'Ad',
                            prefixIcon: Icon(Icons.person_outline, color: blue800),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: grey300),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Soyad',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: grey300),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                ],

                // E-posta Alanı
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email, color: blue800),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: grey300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 20),

                // Şifre Alanı
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(Icons.lock, color: blue800),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: grey300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 8),

                // Şifre hatırlatma (sadece girişte)
                if (!_showRegister)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showError('Şifre sıfırlama özelliği yakında eklenecek');
                      },
                      child: Text(
                        'Şifremi unuttum?',
                        style: TextStyle(color: Color(0xFF1976D2)),
                      ),
                    ),
                  ),

                SizedBox(height: 30),

                // Giriş/Kayıt Butonu
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                        : Text(
                      _showRegister ? 'Hesap Oluştur' : 'Giriş Yap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Giriş/Kayıt Değiştirme
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showRegister
                          ? 'Zaten hesabınız var mı?'
                          : 'Hesabınız yok mu?',
                      style: TextStyle(color: grey600),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                        setState(() {
                          _showRegister = !_showRegister;
                          if (!_showRegister) {
                            _firstNameController.clear();
                            _lastNameController.clear();
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(0, 0),
                      ),
                      child: Text(
                        _showRegister ? 'Giriş Yap' : 'Kayıt Ol',
                        style: TextStyle(
                          color: blue800,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}