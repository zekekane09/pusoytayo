import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
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

  // Web (type-3) OAuth client id from google-services.json. Supplying it as the
  // serverClientId guarantees Google returns an idToken (a common cause of
  // Google sign-in failing on release builds is a null idToken).
  static const String _googleServerClientId =
      '990259222446-af4rmk40kq7c63sr6u7vfb48om27c6k0.apps.googleusercontent.com';

  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser =
          await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled');

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception(
            'Google did not return an ID token. Enable the Google provider in '
            'Firebase Auth and allow your account on the OAuth consent screen.');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return _authenticateWithBackend();
    } catch (e) {
      _logger.e('Google sign-in failed: $e');
      rethrow;
    }
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

  /// Username + password login (accounts created by the admin). Skips Firebase
  /// entirely — goes straight to the backend, like guest.
  Future<UserModel> signInWithUsername(String username, String password) async {
    final response = await _apiClient.post(
      '/auth/login-username',
      data: {'username': username, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _apiClient.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Self sign-up with username + password (100 free, locked coins).
  Future<UserModel> registerWithUsername(
      String username, String password, String displayName) async {
    final deviceId = await _apiClient.getDeviceId();
    final response = await _apiClient.post(
      '/auth/register-username',
      data: {
        'username': username,
        'password': password,
        'displayName': displayName,
        'deviceId': deviceId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _apiClient.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel> signInAsGuest() async {
    // Guest mode skips Firebase entirely so it works with no provider setup —
    // it goes straight to the backend's guest path with a unique id.
    final guestId = const Uuid().v4().replaceAll('-', '');
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        'firebaseToken': 'guest_$guestId',
        'displayName': 'Guest',
        'isGuest': true,
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _apiClient.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
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
