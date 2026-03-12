// lib/main.dart - GÜNCELLENMİŞ VERSİYON (Edge-to-Edge Desteği Eklendi)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- SystemChrome için EKLENDİ
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'create_ad_page.dart';
import 'profile_page.dart';
import 'businesses_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:petmate_flutter/l10n/generated/app_localizations.dart';
import 'providers/locale_provider.dart';

// Global hata değişkenleri
bool _showError = false;
String _errorMessage = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  print('🚀 PetMate uygulaması başlatılıyor...');

  try {
    // 🔥 GERÇEK FIREBASE BİLGİLERİ
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCRyzH5ZheIfzvLPpdij_U_lz7liyKMjn8",
        appId: "1:644126239741:android:baba4d7625ca08cb3ac794",
        messagingSenderId: "644126239741",
        projectId: "petmate-f177e",
        storageBucket: "petmate-f177e.firebasestorage.app",
        databaseURL: "https://petmate-f177e-default-rtdb.firebaseio.com",
      ),
    );

    print('✅ Firebase başarıyla başlatıldı!');

    // Firebase test
    try {
      final database = FirebaseDatabase.instance;
      final testRef = database.ref('connection_test');
      await testRef.set({
        'test': 'PetMate connection test',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await testRef.remove();
      print('✅ Firebase Database testi başarılı');
    } catch (e) {
      print('⚠️ Firebase test hatası: $e');
    }

  } catch (e) {
    print('❌ Firebase başlatma hatası: $e');
    _showError = true;
    _errorMessage = e.toString();
  }

  // 🆕 EDGE-TO-EDGE MODUNU AKTİF ET
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 💎 REVENUECAT BAŞLATMA ALANI
  try {
    if (Platform.isAndroid) {
      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration('goog_trMjQauetHCsCtMVTHLVCbjfkKP');
      await Purchases.configure(configuration);
      print('✅ RevenueCat başarıyla başlatıldı');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await Purchases.logIn(user.uid);
        print('✅ RevenueCat kullanıcı girişi yapıldı: ${user.uid}');
      }
    }
  } catch (e) {
    print('⚠️ RevenueCat başlatılamadı: $e');
  }

  // 🆕 SİSTEM ÇUBUKLARININ RENKLERİNİ AYARLA (İsteğe bağlı)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Status bar şeffaf
      systemNavigationBarColor: Colors.transparent, // Navigation bar şeffaf
      statusBarIconBrightness: Brightness.dark, // Status bar ikonları koyu
      systemNavigationBarIconBrightness: Brightness.dark, // Navigation bar ikonları koyu
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'PetMate - Evcil Hayvan Platformu',
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
        Locale('de'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: _showError
          ? FirebaseErrorScreen(errorMessage: _errorMessage)
          : const AuthWrapper(),
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/createAd': (context) => CreateAdPage(),
        '/profile': (context) => ProfilePage(),
        '/businesses': (context) => BusinessesPage(),
      },
    );
  }
}

// Firebase Hata Ekranı - SafeArea ile güncellendi
class FirebaseErrorScreen extends StatelessWidget {
  final String errorMessage;

  const FirebaseErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetMate - Bağlantı Hatası'),
        backgroundColor: Colors.red,
      ),
      body: SafeArea( // <--- SafeArea EKLENDİ
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Firebase Bağlantı Hatası',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(errorMessage),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Uygulamayı yeniden başlat
                    // (Bu basit bir çözüm, gerçek uygulamada daha iyi bir hata yönetimi yapılabilir)
                  },
                  child: const Text('Tamam'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Auth Wrapper - SafeArea ile güncellendi
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Kullanıcı giriş yapmış, direkt HomePage'e yönlendir
          return HomePage(); // HomePage'in içinde SafeArea var mı kontrol et
        }

        // Kullanıcı giriş yapmamış, LoginPage'e yönlendir
        return LoginPage(); // LoginPage'in içinde SafeArea var mı kontrol et
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: SafeArea( // <--- SafeArea EKLENDİ
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('PetMate yükleniyor...'),
            ],
          ),
        ),
      ),
    );
  }
}