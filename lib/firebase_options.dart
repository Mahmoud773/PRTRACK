import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBPYi5l8lNMWMqrMxwCPZbwRfh1GKaOEQk',
    appId: '1:643836943331:android:29afe43d1bcbdabf0f5ed6',
    messagingSenderId: '643836943331',
    projectId: 'prtrack-benefit',
    storageBucket: 'prtrack-benefit.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-p5J73x_EKu5Mzg6sHY74HjdI4BhawB4',
    appId: '1:643836943331:ios:ab41f444c406d5a80f5ed6',
    messagingSenderId: '643836943331',
    projectId: 'prtrack-benefit',
    storageBucket: 'prtrack-benefit.firebasestorage.app',
    iosBundleId: 'com.benefit.prtrack',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmyW509b36l2uxu2DPprlk1lKFbJpieJs',
    appId: '1:643836943331:web:9ebf04cc824c53850f5ed6',
    messagingSenderId: '643836943331',
    projectId: 'prtrack-benefit',
    authDomain: 'prtrack-benefit.firebaseapp.com',
    storageBucket: 'prtrack-benefit.firebasestorage.app',
  );
}
