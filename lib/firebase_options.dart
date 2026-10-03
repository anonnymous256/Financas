import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

/// Configuração do projeto Firebase `financas-e262b` (app web).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase deste projeto está configurado para a web. '
      'Plataforma atual: ${defaultTargetPlatform.name}.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD5OIpBL2StDNUbZl_0vuIaSseCJm9qh64',
    appId: '1:450487680717:web:999c47e4a61e90414c7384',
    messagingSenderId: '450487680717',
    projectId: 'financas-e262b',
    authDomain: 'financas-e262b.firebaseapp.com',
    storageBucket: 'financas-e262b.firebasestorage.app',
    measurementId: 'G-6QM685JER3',
  );
}

bool get firebaseIsConfigured {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    final key = options.apiKey;
    final project = options.projectId;
    return key.isNotEmpty &&
        project.isNotEmpty &&
        !key.contains('REPLACE') &&
        !project.contains('REPLACE');
  } catch (_) {
    return false;
  }
}
