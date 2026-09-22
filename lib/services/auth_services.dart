import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? usuario;
  bool isLoading = true;

  AuthService() {
    _authCheck();
  }

  void _authCheck() {
    _auth.authStateChanges().listen((User? user) {
      usuario = user;
      isLoading = false;
      notifyListeners();
    });
  }

  void _getUser() {
    usuario = _auth.currentUser;
    notifyListeners();
  }

  Future<void> registrar(String email, String senha) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: senha);
      _getUser();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensagemDoFirebase(e, cadastro: true));
    }
  }

  Future<void> login(String email, String senha) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: senha);
      _getUser();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensagemDoFirebase(e));
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
  }
}