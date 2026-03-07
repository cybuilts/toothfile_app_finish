// ignore_for_file: unused_import
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' deferred as google_signin;

class SupabaseAuthService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      return {
        'success': true,
        'message': 'User created successfully',
        'user': response.user,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return {
        'success': true,
        'message': 'Login successful',
        'user': response.user,
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message, // 'An unknown authentication error occurred.'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      /*
      // Native Google Sign In (Android/iOS)
      // Uncomment this block and the import above when building for Android/iOS.
      // The google_sign_in package causes build errors on Windows.
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        // await google_signin.loadLibrary();
        const webClientId = '788668999922-tidk1a1enrfmsvviomvn2iso08m6ge33.apps.googleusercontent.com';
        const iosClientId = '788668999922-ev0060rn3mnvkuaauth9h2h5doa95sof.apps.googleusercontent.com';

        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
          serverClientId: webClientId,
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          return {
            'success': false,
            'message': 'Google sign in canceled'
          };
        }

        final googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw 'No ID Token found.';
        }

        await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        return {
          'success': true,
          'message': 'Google login successful',
          'user': _supabase.auth.currentUser
        };
      }
      */

      // Web & Desktop Google Sign In (OAuth Flow)
      // This works on Windows as well via browser redirect
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.toothfile://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      return {
        'success': true,
        'message': 'Google login successful',
        'user': _supabase.auth.currentUser,
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
