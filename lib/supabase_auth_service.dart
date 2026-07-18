// ignore_for_file: unused_import
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' deferred as google_signin;
import 'package:http/http.dart' as http;

class SupabaseAuthService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final fullName = userMetadata?['name']?.toString().trim() ?? '';
    final selectedRole = userMetadata?['role']?.toString().trim() ?? '';
    final signupRole = _normalizeSignupRole(selectedRole);

    try {
      // #region debug-point A:signup-invoke
      http.post(
        Uri.parse('http://127.0.0.1:8787/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': 'signup-email-failure',
          'runId': 'pre-fix',
          'hypothesisId': 'A',
          'location': 'supabase_auth_service.dart:signUp:beforeInvoke',
          'msg': '[DEBUG] Invoking signup-with-verification',
          'data': {
            'hasFullName': fullName.isNotEmpty,
            'selectedRole': selectedRole,
            'signupRole': signupRole,
            'passwordLength': password.length,
            'emailLength': normalizedEmail.length,
          },
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      ).catchError((_) {});
      // #endregion
      final response = await _supabase.functions.invoke(
        'signup-with-verification',
        body: {
          'email': normalizedEmail,
          'password': password,
          'fullName': fullName,
          'full_name': fullName,
          'name': fullName,
          'role': signupRole,
          'userRole': signupRole,
          'accountType': signupRole,
          'user_role': signupRole,
          'user_type': signupRole,
          'userType': signupRole,
          'profession': signupRole,
          'roleLabel': signupRole,
          'selectedRole': signupRole,
          'role_key': selectedRole,
          'roleKey': selectedRole,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        // #region debug-point B:signup-non2xx
        http.post(
          Uri.parse('http://127.0.0.1:8787/event'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sessionId': 'signup-email-failure',
            'runId': 'pre-fix',
            'hypothesisId': 'B',
            'location': 'supabase_auth_service.dart:signUp:non2xx',
            'msg': '[DEBUG] Signup function returned non-2xx status',
            'data': {
              'status': response.status,
              'dataType': response.data.runtimeType.toString(),
              'mapKeys': response.data is Map
                  ? (response.data as Map).keys.map((key) => key.toString()).toList()
                  : null,
              'rawData': response.data?.toString(),
            },
            'ts': DateTime.now().millisecondsSinceEpoch,
          }),
        ).catchError((_) {});
        // #endregion
        return {
          'success': false,
          'message': _mapEmailErrorMessage(
            _extractFunctionErrorMessage(
              data: response.data,
              status: response.status,
            ),
          ),
        };
      }

      final functionErrorMessage = _extractFunctionErrorMessage(
        data: response.data,
        status: response.status,
      );
      if (functionErrorMessage != null) {
        // #region debug-point C:signup-structured-error
        http.post(
          Uri.parse('http://127.0.0.1:8787/event'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sessionId': 'signup-email-failure',
            'runId': 'pre-fix',
            'hypothesisId': 'B',
            'location': 'supabase_auth_service.dart:signUp:structuredError',
            'msg': '[DEBUG] Signup function returned structured error payload',
            'data': {
              'status': response.status,
              'dataType': response.data.runtimeType.toString(),
              'mapKeys': response.data is Map
                  ? (response.data as Map).keys.map((key) => key.toString()).toList()
                  : null,
              'functionErrorMessage': functionErrorMessage,
            },
            'ts': DateTime.now().millisecondsSinceEpoch,
          }),
        ).catchError((_) {});
        // #endregion
        return {
          'success': false,
          'message': _mapEmailErrorMessage(functionErrorMessage),
        };
      }

      // #region debug-point D:signup-success
      http.post(
        Uri.parse('http://127.0.0.1:8787/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': 'signup-email-failure',
          'runId': 'pre-fix',
          'hypothesisId': 'D',
          'location': 'supabase_auth_service.dart:signUp:success',
          'msg': '[DEBUG] Signup function returned success',
          'data': {
            'status': response.status,
            'dataType': response.data.runtimeType.toString(),
            'mapKeys': response.data is Map
                ? (response.data as Map).keys.map((key) => key.toString()).toList()
                : null,
          },
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      ).catchError((_) {});
      // #endregion

      return {
        'success': true,
        'message': 'Verification code sent',
        'requiresVerification': true,
      };
    } on FunctionException catch (e) {
      final extractedMessage = _extractFunctionExceptionMessage(e);
      final mappedMessage = _mapEmailErrorMessage(extractedMessage);
      // #region debug-point E:signup-exception
      http.post(
        Uri.parse('http://127.0.0.1:8787/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': 'signup-email-failure',
          'runId': 'pre-fix',
          'hypothesisId': 'C',
          'location': 'supabase_auth_service.dart:signUp:exception',
          'msg': '[DEBUG] Signup function threw exception',
          'data': {
            'errorType': e.runtimeType.toString(),
            'error': e.toString(),
            'extractedMessage': extractedMessage,
            'mappedMessage': mappedMessage,
          },
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      ).catchError((_) {});
      // #endregion
      return {
        'success': false,
        'message': mappedMessage,
      };
    } catch (e) {
      // #region debug-point E:signup-exception
      http.post(
        Uri.parse('http://127.0.0.1:8787/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': 'signup-email-failure',
          'runId': 'pre-fix',
          'hypothesisId': 'C',
          'location': 'supabase_auth_service.dart:signUp:exception',
          'msg': '[DEBUG] Signup function threw exception',
          'data': {
            'errorType': e.runtimeType.toString(),
            'error': e.toString(),
          },
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      ).catchError((_) {});
      // #endregion
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
    }
  }

  static Future<Map<String, dynamic>> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.email,
      );

      return {
        'success': true,
        'message': 'Email verified successfully',
        'session': response.session,
        'user': response.user,
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
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

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
  }) async {
    try {
      final redirectTo =
          !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? 'io.toothfile.app://reset-password'
          : 'https://toothfile.com/set-password';
      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: redirectTo,
      );
      return {
        'success': true,
        'message': 'Password reset email sent',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
    }
  }

  static Future<Map<String, dynamic>> sendMagicLink({
    required String email,
  }) async {
    try {
      await _supabase.auth.signInWithOtp(email: email.trim().toLowerCase());
      return {
        'success': true,
        'message': 'Magic link sent',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': _mapEmailErrorMessage(e)};
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

  static String _mapEmailErrorMessage(Object? error) {
    final message = (error ?? '').toString().toLowerCase();

    if (message.contains('invalid email') || message.contains('statuscode: 400')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('full name')) {
      return 'Please enter your full name.';
    }
    if (message.contains('dentist or dental technician')) {
      return 'Please choose Dentist or Dental Technician.';
    }
    if (message.contains('already registered') ||
        message.contains('user already registered') ||
        message.contains('statuscode: 409')) {
      return 'This email is already registered. Try signing in.';
    }
    if (message.contains('rate limit') || message.contains('statuscode: 429')) {
      return 'Too many requests. Please try again in a minute.';
    }
    if (message.contains('network') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('statuscode: 500')) {
      return 'Couldn\'t send email. Please try again shortly.';
    }
    if (message.contains('invalid token') ||
        message.contains('otp') ||
        message.contains('token')) {
      return 'That code is invalid or expired. Please try again.';
    }
    final rawMessage = error?.toString().trim() ?? '';
    if (rawMessage.isNotEmpty &&
        !rawMessage.toLowerCase().startsWith('functionexception(') &&
        rawMessage.length <= 180) {
      return rawMessage;
    }
    return 'Couldn\'t send email. Please try again shortly.';
  }

  static String? _extractFunctionErrorMessage({
    required dynamic data,
    required int status,
  }) {
    String? pickMessage(Map<dynamic, dynamic> map) {
      for (final key in const [
        'error',
        'message',
        'msg',
        'details',
        'error_description',
      ]) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    if (data is Map) {
      final explicitError = pickMessage(data);
      final success = data['success'];
      if (success == false) {
        return explicitError ?? 'statuscode: $status';
      }
      if (status >= 400) {
        return explicitError ?? 'statuscode: $status';
      }
      return null;
    }

    if (data is String && data.trim().isNotEmpty) {
      if (status >= 400) {
        return data.trim();
      }
      final normalized = data.trim().toLowerCase();
      if (normalized.contains('"success":false') || normalized.contains('"error"')) {
        return data.trim();
      }
    }

    if (status >= 400) {
      return 'statuscode: $status';
    }

    return null;
  }

  static String _extractFunctionExceptionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      for (final key in const [
        'error',
        'message',
        'msg',
        'details',
        'error_description',
      ]) {
        final value = details[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    return error.toString();
  }

  static String _normalizeSignupRole(String role) {
    switch (role.toLowerCase()) {
      case 'dental':
      case 'dentist':
        return 'Dentist';
      case 'technician':
      case 'dental technician':
        return 'Dental Technician';
      default:
        return role;
    }
  }
}
