import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase başlatıldı');
    } catch (e) {
      print('❌ Firebase başlatma hatası: $e');
      throw Exception('Firebase başlatılamadı: $e');
    }
  }

  // Firebase kurallarını kontrol et
  static void checkRules() {
    print('''
    🔥 FIREBASE KURAL KONTROLÜ:
    
    1. Realtime Database Rules:
    {
      "rules": {
        "ads": {
          ".read": true,
          ".write": "auth != null"
        },
        "users": {
          "$uid": {
            ".read": "auth != null",
            ".write": "auth != null && auth.uid == $uid"
          }
        }
      }
    }
    
    2. Storage Rules:
    rules_version = '2';
    service firebase.storage {
      match /b/{bucket}/o {
        match /ads/{adId}/{fileName} {
          allow read: if true;
          allow write: if request.auth != null;
        }
      }
    }
    ''');
  }
}