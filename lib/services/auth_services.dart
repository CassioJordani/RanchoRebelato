import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? auth, FirestoreService? firestoreService})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestoreService = firestoreService ?? FirestoreService() {
    if (_usesWindowsAuthWorkaround) {
      isLoading = false;
    } else {
      _authSubscription = _auth.authStateChanges().listen(
        (user) => unawaited(_handleAuthState(user)),
        onError: _handleAuthError,
      );
    }
  }

  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  StreamSubscription<User?>? _authSubscription;
  User? usuario;
  bool isLoading = true;
  Object? initializationError;

  bool get _usesWindowsAuthWorkaround =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _handleAuthState(User? user) async {
    usuario = user;
    initializationError = null;
    if (user != null) {
      isLoading = true;
      notifyListeners();
      try {
        await _firestoreService.ensureViewerProfile(user);
      } on FirebaseException catch (error) {
        initializationError = error;
      } on StateError catch (error) {
        initializationError = error;
      }
    }
    isLoading = false;
    notifyListeners();
  }

  void _handleAuthError(Object error) {
    initializationError = error;
    isLoading = false;
    notifyListeners();
  }

  void _getUser() {
    if (_usesWindowsAuthWorkaround) {
      unawaited(_handleAuthState(_auth.currentUser));
      return;
    }
    usuario = _auth.currentUser;
    notifyListeners();
  }

  Future<void> registrar(String email, String senha) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      await _handleAuthenticationResult(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensagemDoFirebase(e, cadastro: true));
    }
  }

  Future<void> login(String email, String senha) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      await _handleAuthenticationResult(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensagemDoFirebase(e));
    }
  }

  Future<void> _handleAuthenticationResult(UserCredential credential) async {
    if (_usesWindowsAuthWorkaround) {
      await _handleAuthState(credential.user);
    } else {
      _getUser();
    }
  }

  String _mensagemDoFirebase(
    FirebaseAuthException error, {
    bool cadastro = false,
  }) {
    switch (error.code) {
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      case 'email-already-in-use':
        return 'Este email já está cadastrado.';
      case 'invalid-email':
        return 'Informe um email válido.';
      case 'operation-not-allowed':
        return cadastro
            ? 'O cadastro por Email/Senha está desativado no Firebase. '
                  'Ative-o em Authentication > Sign-in method.'
            : 'O login por Email/Senha está desativado no Firebase.';
      case 'user-not-found':
        return 'Email não encontrado. Cadastre-se.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou senha inválidos.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      default:
        return 'Firebase recusou a operação (${error.code}).';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    if (_usesWindowsAuthWorkaround) {
      await _handleAuthState(null);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
