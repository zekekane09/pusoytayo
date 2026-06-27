import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/features/auth/data/auth_repository.dart';
import 'package:pusoy_tayo/features/auth/domain/user_model.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserModel?>(AuthController.new);

class AuthController extends AsyncNotifier<UserModel?> {
  late AuthRepository _repo;

  @override
  Future<UserModel?> build() async {
    _repo = ref.watch(authRepositoryProvider);
    if (_repo.currentFirebaseUser != null) {
      return _repo.getCurrentUser();
    }
    return null;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithGoogle());
  }

  Future<void> signInWithFacebook() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithFacebook());
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithApple());
  }

  Future<void> signInAsGuest() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInAsGuest());
  }

  /// Local demo login — bypasses Firebase and the backend so the UI can be
  /// explored offline. Intended for debug builds only (see LoginScreen).
  Future<void> signInAsDemo() async {
    state = AsyncData(
      UserModel(
        id: 'demo-user',
        firebaseUid: 'demo',
        displayName: 'Demo Player',
        authProvider: 'demo',
        isGuest: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(null);
  }
}
