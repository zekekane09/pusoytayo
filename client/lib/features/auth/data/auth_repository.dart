import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:logger/logger.dart';
import 'package:pusoy_tayo/core/constants/api_endpoints.dart';
import 'package:pusoy_tayo/core/network/api_client.dart';
import 'package:pusoy_tayo/features/auth/domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthRepository {
  final ApiClient _apiClient;
  // `late` so the instance is only resolved on first access — accessing it
  // before Firebase.initializeApp() succeeds throws [core/no-app].
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final _logger = Logger();

  AuthRepository(this._apiClient);

  /// Returns null when Firebase isn't configured/initialized instead of
  /// throwing, so app startup (AuthController.build) stays clean.
  User? get currentFirebaseUser {
    try {
      return _firebaseAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserModel> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _firebaseAuth.signInWithCredential(credential);
    return _authenticateWithBackend();
  }

  Future<UserModel> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success) {
      throw Exception('Facebook sign in failed: ${result.message}');
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );

    await _firebaseAuth.signInWithCredential(credential);
    return _authenticateWithBackend();
  }

  Future<UserModel> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    await _firebaseAuth.signInWithCredential(oauthCredential);
    return _authenticateWithBackend();
  }

  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw Exception('Phone verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        _logger.i('OTP sent to $phoneNumber');
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserModel> verifyPhoneOtp(String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    await _firebaseAuth.signInWithCredential(credential);
    return _authenticateWithBackend();
  }

  Future<UserModel> signInAsGuest() async {
    await _firebaseAuth.signInAnonymously();
    return _authenticateWithBackend();
  }

  Future<UserModel> _authenticateWithBackend() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No Firebase user');

    final idToken = await user.getIdToken();

    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        'firebaseToken': idToken,
        'displayName': user.displayName ?? 'Player',
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'avatarUrl': user.photoURL,
        'isGuest': user.isAnonymous,
      },
    );

    final data = response.data as Map<String, dynamic>;
    await _apiClient.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.profile);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Failed to get current user: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await GoogleSignIn().signOut();
    await _apiClient.clearTokens();
  }
}
