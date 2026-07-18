// ignore_for_file: unused_element, unused_local_variable

import 'dart:io';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:toothfile/dashboard_page.dart';
import 'package:toothfile/quick_share_service.dart';
import 'package:toothfile/device_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/supabase_auth_service.dart';
// import 'package:firebase_core/firebase_core.dart';  // Temporarily disabled for Windows Release build
// import 'package:firebase_messaging/firebase_messaging.dart';  // Temporarily disabled for Windows Release build
import 'package:toothfile/push_notification_service.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Optional local notifications for mobile platforms only
// Removed global plugin setup on desktop to avoid unsupported initialization

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
bool _supabaseReady = false;
String? _initError;
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

// MethodChannel for Windows Deep Linking
const _methodChannel = MethodChannel('com.example.toothfile/deeplink');
const _primaryWebHost = 'toothfile.com';
const _supabaseProjectHost = 'ikqsbkfnjamvkevsxqpr.supabase.co';

final ValueNotifier<_PendingInviteContext?> _pendingInviteNotifier =
    ValueNotifier(null);
final ValueNotifier<bool> _emailVerifiedNotifier = ValueNotifier(false);
final ValueNotifier<bool> _passwordRecoveryNotifier = ValueNotifier(false);
final ValueNotifier<bool> _forceAuthScreenNotifier = ValueNotifier(false);

class _PendingInviteContext {
  const _PendingInviteContext({required this.invitedBy});

  final String invitedBy;
}

ThemeMode themeModeFromPreference(String theme) {
  switch (theme) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

void updateAppThemeMode(String theme) {
  appThemeModeNotifier.value = themeModeFromPreference(theme);
}

void _openSendTabIfSignedIn() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return;
  }
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const DashboardPage(initialIndex: 1)),
    (route) => false,
  );
}

List<String> _extractQuickSharePaths(List<String> args) {
  if (args.isEmpty) {
    return [];
  }
  final paths = <String>[];
  var quickShareMode = false;
  for (final arg in args) {
    if (arg == '--quick-share') {
      quickShareMode = true;
      continue;
    }
    if (quickShareMode || File(arg).existsSync()) {
      paths.add(arg);
    }
  }
  return paths;
}

Future<void> _handleWindowsLaunchPayload(String payload) async {
  if (payload.trim().isEmpty) {
    return;
  }
  final uri = Uri.tryParse(payload);
  if (uri != null && uri.scheme == 'io.supabase.toothfile') {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
    return;
  }
  if (uri != null) {
    final handled = await _handleIncomingAuthUri(uri);
    if (handled) {
      return;
    }
  }
  final args = payload.contains('\n')
      ? payload.split('\n').where((value) => value.trim().isNotEmpty).toList()
      : [payload];
  final quickSharePaths = _extractQuickSharePaths(args);
  if (quickSharePaths.isEmpty) {
    return;
  }
  QuickShareService.addPendingFiles(quickSharePaths);
  _openSendTabIfSignedIn();
}

bool _isTrustedDeepLinkHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == _primaryWebHost || host == _supabaseProjectHost;
}

Future<void> _routeToDashboardIfSignedIn() async {
  if (_passwordRecoveryNotifier.value) {
    return;
  }
  _forceAuthScreenNotifier.value = false;
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return;
  }
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const DashboardPage()),
    (route) => false,
  );
}

Future<void> _routeToAuth() async {
  _forceAuthScreenNotifier.value = true;
  _passwordRecoveryNotifier.value = false;
  _emailVerifiedNotifier.value = false;
  _pendingInviteNotifier.value = null;
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthPage()),
    (route) => false,
  );
}

Map<String, String> _extractDeepLinkParameters(Uri uri) {
  final parameters = <String, String>{...uri.queryParameters};
  final fragment = uri.fragment.trim();
  if (fragment.isNotEmpty && fragment.contains('=')) {
    try {
      parameters.addAll(Uri.splitQueryString(fragment));
    } catch (_) {}
  }
  return parameters;
}

bool _isPasswordRecoveryUri(Uri uri) {
  if (uri.scheme == 'io.toothfile.app' && uri.host == 'reset-password') {
    return true;
  }
  final type = _extractDeepLinkParameters(uri)['type']?.toLowerCase();
  return type == 'recovery';
}

Future<void> _routeToSetPassword() async {
  _passwordRecoveryNotifier.value = true;
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.pushNamedAndRemoveUntil('/set-password', (route) => false);
}

Future<bool> _handleIncomingAuthUri(Uri uri) async {
  if (uri.scheme == 'io.toothfile.app' && uri.host == 'reset-password') {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
    await _routeToSetPassword();
    return true;
  }

  if (!_isTrustedDeepLinkHost(uri)) {
    return false;
  }

  if (uri.path == '/auth/callback' || uri.path == '/set-password') {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
    if (_isPasswordRecoveryUri(uri) || uri.path == '/set-password') {
      await _routeToSetPassword();
    } else {
      await _routeToDashboardIfSignedIn();
    }
    return true;
  }

  if (uri.path == '/auth') {
    final invitedBy = uri.queryParameters['invited_by']?.trim();
    if (invitedBy != null && invitedBy.isNotEmpty) {
      _pendingInviteNotifier.value = _PendingInviteContext(invitedBy: invitedBy);
      return true;
    }
  }

  if (uri.path == '/email-verified') {
    _emailVerifiedNotifier.value = true;
    await _routeToDashboardIfSignedIn();
    return true;
  }

  return false;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up MethodCallHandler for Deep Links (Windows)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String payload = call.arguments as String;
        try {
          await _handleWindowsLaunchPayload(payload);
        } catch (_) {
          debugPrint('Deep link handling failed.');
        }
      }
    });
  }

  // Set up deep link handling for macOS
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    // Note: The app_links package should be used to listen for deep links on macOS
    // However, since we don't have it installed/configured yet, we rely on the
    // default deep link handling which usually passes the URL to the app.
    // If you need specific handling, consider adding 'app_links' or 'uni_links'.
  }

  // Firebase temporarily disabled for Windows Release build
  /*
  if (kIsWeb ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS))) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }
  */

  try {
    await Supabase.initialize(
      url: 'https://ikqsbkfnjamvkevsxqpr.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrcXNia2ZuamFtdmtldnN4cXByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzNTUxMDMsImV4cCI6MjA2NTkzMTEwM30.fhRMXkOu8WAD6B_zMCe1xBI6E_Ql4pRzRnfJHZS7qPM',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _supabaseReady = true;
  } catch (e) {
    _initError = e.toString();
  }

  PushNotificationService.initialize(_navigatorKey);

  QuickShareService.addPendingFiles(_extractQuickSharePaths(args));

  // P2P functionality removed - no initialization needed

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initDeepLinks();
    _authSubscription = SupabaseAuthService.authStateChanges.listen((auth) async {
      if (auth.event == AuthChangeEvent.passwordRecovery) {
        _forceAuthScreenNotifier.value = false;
        await _routeToSetPassword();
      } else if (auth.event == AuthChangeEvent.signedIn ||
          auth.event == AuthChangeEvent.tokenRefreshed) {
        _forceAuthScreenNotifier.value = false;
        await DeviceService.instance.initializeForSignedInUser();
      } else if (auth.event == AuthChangeEvent.signedOut) {
        _passwordRecoveryNotifier.value = false;
        await DeviceService.instance.markSignedOut();
        await _routeToAuth();
      }
    });

    if (Supabase.instance.client.auth.currentUser != null) {
      DeviceService.instance.initializeForSignedInUser();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('selected_theme') ?? 'system';
    appThemeModeNotifier.value = themeModeFromPreference(theme);
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) {
      final uri = Uri.base;
      await _handleIncomingAuthUri(uri);
      return;
    }

    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingAuthUri(initialUri);
      }
    } catch (_) {}

    _appLinksSubscription = _appLinks!.uriLinkStream.listen((uri) async {
      await _handleIncomingAuthUri(uri);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'ToothFile',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          navigatorKey: _navigatorKey,
          routes: {
            '/dashboard': (_) => const DashboardPage(),
            '/set-password': (_) => const SetPasswordScreen(),
          },
          home: ValueListenableBuilder<bool>(
            valueListenable: _emailVerifiedNotifier,
            builder: (context, emailVerified, child) {
              if (emailVerified) {
                return EmailVerifiedSuccessPage(
                  onContinue: () {
                    _emailVerifiedNotifier.value = false;
                    _routeToDashboardIfSignedIn();
                  },
                );
              }

              return ValueListenableBuilder<bool>(
                valueListenable: _passwordRecoveryNotifier,
                builder: (context, passwordRecovery, child) {
                  if (passwordRecovery) {
                    return const SetPasswordScreen();
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: _forceAuthScreenNotifier,
                    builder: (context, forceAuthScreen, child) {
                      if (forceAuthScreen) {
                        return const AuthPage();
                      }

                      return StreamBuilder<AuthState>(
                        stream: SupabaseAuthService.authStateChanges,
                        builder: (context, snapshot) {
                          if (!_supabaseReady) return const AuthPage();
                          final user = Supabase.instance.client.auth.currentUser;

                          if (user != null) {
                            return DashboardPage(
                              initialIndex: QuickShareService.hasPendingFiles
                                  ? 1
                                  : null,
                            );
                          } else {
                            return const AuthPage();
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Auth Page
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isSignInSelected = true;
  bool _isLoading = false;
  bool _signInPasswordVisible = false;
  bool _signUpPasswordVisible = false;
  bool _showVerificationStep = false;
  int _resendCooldownSeconds = 0;

  Timer? _resendCooldownTimer;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();

  String? _selectedRole;
  String? _verificationEmail;
  String? _verificationPassword;
  String? _verificationFullName;
  String? _verificationRole;
  TapGestureRecognizer? _termsRecognizer;
  TapGestureRecognizer? _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse('https://toothfile.com/terms-of-use');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse('https://toothfile.com/privacy-policy');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _pendingInviteNotifier.addListener(_handleInviteContextChanged);
    _handleInviteContextChanged();

    // Initialize TouchBar after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTouchBar();
    });
  }

  void _updateTouchBar() {
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [
        TouchBarHelperAction(
          label: 'Google Auth',
          action: () async {
            // Trigger Google Auth
            setState(() => _isLoading = true);
            final response = await SupabaseAuthService.signInWithGoogle();
            if (!mounted) return;
            setState(() => _isLoading = false);
            // Handle response...
          },
        ),
        TouchBarHelperAction(
          label: _showVerificationStep
              ? 'Verify Email'
              : _pendingInviteNotifier.value != null
              ? 'Create Account'
              : 'Sign In',
          action: () {
            if (_showVerificationStep) {
              _handleVerifyCode();
            } else if (_pendingInviteNotifier.value != null) {
              _handleSignUp();
            } else {
              _handleSignIn();
            }
          },
          isPrimary: true,
        ),
      ],
    );
  }

  void _handleInviteContextChanged() {
    if (!mounted) {
      return;
    }
    final invite = _pendingInviteNotifier.value;
    if (invite != null && _isSignInSelected) {
      setState(() {
        _isSignInSelected = false;
      });
    }
  }

  void _showMessage(String message, {required Color color, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendCooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = seconds;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldownSeconds = 0;
          });
        }
        return;
      }
      setState(() {
        _resendCooldownSeconds -= 1;
      });
    });
  }

  void _enterVerificationStep({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) {
    setState(() {
      _showVerificationStep = true;
      _verificationEmail = email.trim().toLowerCase();
      _verificationPassword = password;
      _verificationFullName = fullName.trim();
      _verificationRole = role;
      _verificationCodeController.clear();
    });
    _startResendCooldown();
  }

  void _exitVerificationStep() {
    _resendCooldownTimer?.cancel();
    setState(() {
      _showVerificationStep = false;
      _resendCooldownSeconds = 0;
      _verificationCodeController.clear();
      _verificationEmail = null;
      _verificationPassword = null;
      _verificationFullName = null;
      _verificationRole = null;
    });
  }

  Future<void> _handleSignIn() async {
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Please enter both email and password',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await SupabaseAuthService.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      await PushNotificationService.ensurePermissionsAndSyncToken();
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardPage()),
        (Route<dynamic> route) => false,
      );
    } else {
      _showMessage(
        response['message'],
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showMessage(
        'Enter your email first to reset your password.',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final response = await SupabaseAuthService.resetPassword(email: email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    _showMessage(
      response['message'],
      color: response['success']
          ? const Color(0xFF16A34A)
          : const Color(0xFFEF4444),
      icon: response['success']
          ? Icons.mark_email_read_rounded
          : Icons.error_outline_rounded,
    );
  }

  Future<void> _handleMagicLinkSignIn() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showMessage(
        'Enter your email first to receive a magic link.',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final response = await SupabaseAuthService.sendMagicLink(email: email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    _showMessage(
      response['message'],
      color: response['success']
          ? const Color(0xFF16A34A)
          : const Color(0xFFEF4444),
      icon: response['success']
          ? Icons.mark_email_read_rounded
          : Icons.error_outline_rounded,
    );
  }

  Future<void> _handleVerifyCode() async {
    final email = _verificationEmail;
    final fullName = _verificationFullName;
    final role = _verificationRole;
    final code = _verificationCodeController.text.trim();

    if (email == null || fullName == null || role == null) {
      _showMessage(
        'Please start the signup process again.',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
      _exitVerificationStep();
      return;
    }
    if (code.length != 6) {
      _showMessage(
        'Enter the 6-digit verification code.',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await SupabaseAuthService.verifyEmailCode(
      email: email,
      code: code,
    );

    if (!mounted) return;

    if (response['success']) {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'name': fullName, 'role': role}),
      );
      await PushNotificationService.ensurePermissionsAndSyncToken();
      setState(() {
        _isLoading = false;
      });
      _showMessage(
        'Email verified successfully.',
        color: const Color(0xFF16A34A),
        icon: Icons.check_circle_outline_rounded,
      );
      _exitVerificationStep();
      _pendingInviteNotifier.value = null;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardPage()),
        (Route<dynamic> route) => false,
      );
      return;
    }

    setState(() {
      _isLoading = false;
    });
    _showMessage(
      response['message'],
      color: const Color(0xFFEF4444),
      icon: Icons.error_outline_rounded,
    );
  }

  Future<void> _handleResendCode() async {
    if (_resendCooldownSeconds > 0) {
      return;
    }
    final email = _verificationEmail;
    final password = _verificationPassword;
    final fullName = _verificationFullName;
    final role = _verificationRole;
    if (email == null || password == null || fullName == null || role == null) {
      _exitVerificationStep();
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final response = await SupabaseAuthService.signUp(
      email: email,
      password: password,
      userMetadata: {'name': fullName, 'role': role},
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _startResendCooldown();
      _showMessage(
        'Verification code sent',
        color: const Color(0xFF16A34A),
        icon: Icons.mark_email_read_rounded,
      );
    } else {
      _showMessage(
        response['message'],
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _handleSignUp() async {
    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _selectedRole == null) {
      _showMessage(
        'Please fill in all fields and select a role',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await SupabaseAuthService.signUp(
      email: email,
      password: password,
      userMetadata: {'role': _selectedRole, 'name': fullName},
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _enterVerificationStep(
        email: email,
        password: password,
        fullName: fullName,
        role: _selectedRole!,
      );
      _showMessage(
        'Verification code sent to $email',
        color: const Color(0xFF16A34A),
        icon: Icons.mark_email_read_rounded,
      );
    } else {
      _showMessage(
        response['message'],
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    _termsRecognizer?.dispose();
    _privacyRecognizer?.dispose();
    _pendingInviteNotifier.removeListener(_handleInviteContextChanged);
    super.dispose();
  }

  Widget _buildSignInForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Email',
            style: TextStyle(
              color: Color(0xFF020817),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Password',
            style: TextStyle(
              color: Color(0xFF020817),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_signInPasswordVisible,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _signInPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _signInPasswordVisible = !_signInPasswordVisible;
                        });
                      },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: const Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: const Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                      });

                      final response =
                          await SupabaseAuthService.signInWithGoogle();

                      if (!mounted) return;

                      setState(() {
                        _isLoading = false;
                      });

                      if (response['success']) {
                        // Wait for AuthState change to redirect
                      } else if (response['message'] !=
                          'Google sign in canceled') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    response['message'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                            elevation: 4,
                          ),
                        );
                      }
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Image.asset(
                'assets/google-logo.png',
                height: 20,
                width: 20,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.login, size: 20),
              ),
              label: const Text(
                'Sign in with Google',
                style: TextStyle(
                  color: Color(0xFF020817),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingInviteNotifier.value != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mail_outline_rounded, color: Color(0xFF2563EB)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You opened an invitation link. Create your account to continue.',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Full Name',
              style: TextStyle(
                color: Color(0xFF020817),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fullNameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Email',
              style: TextStyle(
                color: Color(0xFF020817),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Password',
              style: TextStyle(
                color: Color(0xFF020817),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_signUpPasswordVisible,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Create a password',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    _signUpPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _signUpPasswordVisible = !_signUpPasswordVisible;
                          });
                        },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'I am a:',
              style: TextStyle(
                color: Color(0xFF020817),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _selectedRole = 'dental';
                        });
                      },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _selectedRole == 'dental'
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _selectedRole == 'dental'
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  'Dentist',
                  style: TextStyle(
                    color: _selectedRole == 'dental'
                        ? Colors.white
                        : const Color(0xFF020817),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _selectedRole = 'technician';
                        });
                      },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _selectedRole == 'technician'
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _selectedRole == 'technician'
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  'Dental Technician',
                  style: TextStyle(
                    color: _selectedRole == 'technician'
                        ? Colors.white
                        : const Color(0xFF020817),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'By creating an account, you agree to our ',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms of Use',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _termsRecognizer,
                    ),
                    const TextSpan(
                      text: ' and ',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _privacyRecognizer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() {
                          _isLoading = true;
                        });

                        final response =
                            await SupabaseAuthService.signInWithGoogle();

                        if (!mounted) return;

                        setState(() {
                          _isLoading = false;
                        });

                        if (response['success']) {
                          // Wait for AuthState change to redirect
                        } else if (response['message'] !=
                            'Google sign in canceled') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      response['message'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                              elevation: 4,
                            ),
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Image.asset(
                  'assets/google-logo.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.login, size: 20),
                ),
                label: const Text(
                  'Sign up with Google',
                  style: TextStyle(
                    color: Color(0xFF020817),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    final email = _verificationEmail ?? _emailController.text.trim().toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter verification code',
            style: TextStyle(
              color: Color(0xFF020817),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to $email',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _verificationCodeController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Check your spam folder. The email comes from verification@toothfile.com.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Verify Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_isLoading || _resendCooldownSeconds > 0)
                  ? null
                  : _handleResendCode,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _resendCooldownSeconds > 0
                    ? 'Resend code in ${_resendCooldownSeconds}s'
                    : 'Resend code',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isLoading ? null : _exitVerificationStep,
              child: const Text('Wrong email?'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              _showVerificationStep
                                  ? 'Verify your email'
                                  : _pendingInviteNotifier.value != null
                                  ? 'Create your account'
                                  : 'Welcome',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF020817),
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _showVerificationStep
                                  ? 'Enter the 6-digit code to finish creating your account'
                                  : _pendingInviteNotifier.value != null
                                  ? 'Complete your invited account setup'
                                  : 'Sign in to your account',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _showVerificationStep
                          ? _buildVerificationForm()
                          : _pendingInviteNotifier.value != null
                          ? _buildSignUpForm()
                          : _buildSignInForm(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  void _showMessage(String message, {required Color color, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      _showMessage(
        'Min 6 characters.',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (password != confirmPassword) {
      _showMessage(
        'Passwords do not match.',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'password_setup_completed': true})
              .eq('id', uid);
        } catch (_) {}
      }

      _passwordRecoveryNotifier.value = false;
      if (!mounted) {
        return;
      }
      _showMessage(
        'Password updated.',
        color: const Color(0xFF16A34A),
        icon: Icons.check_circle_outline_rounded,
      );
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(
        e.message,
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Unable to update your password right now.',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set new password',
                        style: TextStyle(
                          color: Color(0xFF020817),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a new password to finish your password recovery.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'New password',
                        style: TextStyle(
                          color: Color(0xFF020817),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Enter your new password',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Confirm password',
                        style: TextStyle(
                          color: Color(0xFF020817),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Re-enter your new password',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _confirmPasswordVisible =
                                          !_confirmPasswordVisible;
                                    });
                                  },
                            icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Update Password',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerifiedSuccessPage extends StatelessWidget {
  const EmailVerifiedSuccessPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Email verified',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF020817),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your ToothFile email link was confirmed successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
