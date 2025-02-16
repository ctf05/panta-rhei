import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyDnf9__vO-draVp0vLuoJhp3ro6x6Oe_NI",
      authDomain: "panta-rhei-64246.firebaseapp.com",
      projectId: "panta-rhei-64246",
      storageBucket: "panta-rhei-64246.firebasestorage.app",
      messagingSenderId: "178357664880",
      appId: "1:178357664880:web:f684420e31d88eb19608b5",
      measurementId: "G-9F6BEN8TQ1"
  );

  static const FirebaseOptions android = FirebaseOptions(
      apiKey: "AIzaSyDnf9__vO-draVp0vLuoJhp3ro6x6Oe_NI",
      authDomain: "panta-rhei-64246.firebaseapp.com",
      projectId: "panta-rhei-64246",
      storageBucket: "panta-rhei-64246.firebasestorage.app",
      messagingSenderId: "178357664880",
      appId: "1:178357664880:web:f684420e31d88eb19608b5",
      measurementId: "G-9F6BEN8TQ1"
  );

  static const FirebaseOptions ios = FirebaseOptions(
      apiKey: "AIzaSyDnf9__vO-draVp0vLuoJhp3ro6x6Oe_NI",
      authDomain: "panta-rhei-64246.firebaseapp.com",
      projectId: "panta-rhei-64246",
      storageBucket: "panta-rhei-64246.firebasestorage.app",
      messagingSenderId: "178357664880",
      appId: "1:178357664880:web:f684420e31d88eb19608b5",
      measurementId: "G-9F6BEN8TQ1"
  );

  static const FirebaseOptions macos = FirebaseOptions(
      apiKey: "AIzaSyDnf9__vO-draVp0vLuoJhp3ro6x6Oe_NI",
      authDomain: "panta-rhei-64246.firebaseapp.com",
      projectId: "panta-rhei-64246",
      storageBucket: "panta-rhei-64246.firebasestorage.app",
      messagingSenderId: "178357664880",
      appId: "1:178357664880:web:f684420e31d88eb19608b5",
      measurementId: "G-9F6BEN8TQ1"
  );
}