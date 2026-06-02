import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kTrueBlack = Color(0xFF0A0A0A);
const Color kNearBlack = Color(0xFF0A0A0A);
const Color kSilver = Color(0xFFC0C0C0);
const Color kNavy = Color(0xFF0F1F2E);
const Color kLightNavy = Color(0xFF1C3A5A);
const Color kVibrantRed = Color(0xFFE10600);
const Color kDarkRed = Color(0xFF8B0000);
const Color kDarkGray = Color(0xFF4A4A4A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LinkUpApp());
}

class LinkUpApp extends StatelessWidget {
  const LinkUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.ibmPlexSansTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LinkUP',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: kNavy,
          secondary: kVibrantRed,
          surface: Colors.white,
          onSurface: kNearBlack,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(baseText).apply(
          bodyColor: kNearBlack,
          displayColor: kNearBlack,
        ),
        inputDecorationTheme: _inputDecorationTheme(Brightness.light),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kNavy,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kTrueBlack,
        colorScheme: const ColorScheme.dark(
          primary: kSilver,
          secondary: kVibrantRed,
          surface: kTrueBlack,
          onSurface: kSilver,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(baseText).apply(
          bodyColor: kSilver,
          displayColor: kSilver,
        ),
        inputDecorationTheme: _inputDecorationTheme(Brightness.dark),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kLightNavy,
          contentTextStyle: TextStyle(color: kSilver),
        ),
      ),
      home: const AppBootstrapper(),
    );
  }

  InputDecorationTheme _inputDecorationTheme(Brightness brightness) {
    final borderColor = brightness == Brightness.dark ? kDarkGray : kLightNavy;
    final fillColor = brightness == Brightness.dark
        ? const Color(0xFF141414)
        : const Color(0xFFF6F8FB);

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      labelStyle: TextStyle(
        color: brightness == Brightness.dark ? kSilver : kDarkGray,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kVibrantRed, width: 1.4),
      ),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final AccountStorage _storage = AccountStorage();

  bool _isLoading = true;
  StoredAccount? _account;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final account = await _storage.readLocalAccount();
    if (!mounted) {
      return;
    }
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _handleCreated(StoredAccount account) async {
    await _storage.saveLocalAccount(account);
    if (!mounted) {
      return;
    }
    setState(() {
      _account = account;
      _isAuthenticated = true;
    });
  }

  Future<void> _handleImported(StoredAccount account) async {
    await _storage.saveLocalAccount(account);
    if (!mounted) {
      return;
    }
    setState(() {
      _account = account;
      _isAuthenticated = true;
    });
  }

  void _handleLogin(StoredAccount account) {
    setState(() {
      _account = account;
      _isAuthenticated = true;
    });
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kVibrantRed)),
      );
    }

    if (_account == null) {
      return OnboardingScreen(
        storage: _storage,
        onAccountCreated: _handleCreated,
        onAccountImported: _handleImported,
      );
    }

    if (!_isAuthenticated) {
      return LoginScreen(account: _account!, onAuthenticated: _handleLogin);
    }

    return HomeShell(account: _account!, onLogout: _handleLogout);
  }
}

class StoredAccount {
  const StoredAccount({
    required this.name,
    required this.phoneNumber,
    required this.passwordHash,
    required this.createdAt,
  });

  final String name;
  final String phoneNumber;
  final String passwordHash;
  final String createdAt;

  String get contactKey {
    final seed = '$createdAt|$name|$phoneNumber|$passwordHash';
    return 'linkup:${sha256.convert(utf8.encode(seed)).toString().substring(0, 32)}';
  }

  String get initials {
    if (name.trim().isEmpty) {
      return 'LU';
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'passwordHash': passwordHash,
      'createdAt': createdAt,
    };
  }

  factory StoredAccount.fromJson(Map<String, dynamic> json) {
    return StoredAccount(
      name: (json['name'] as String? ?? '').trim(),
      phoneNumber: (json['phoneNumber'] as String? ?? '').trim(),
      passwordHash: (json['passwordHash'] as String? ?? '').trim(),
      createdAt: (json['createdAt'] as String? ?? DateTime.now().toIso8601String()).trim(),
    );
  }
}

class AccountStorage {
  static const String _localAccountKey = 'linkup.local.account';

  Future<StoredAccount?> readLocalAccount() async {
    final preferences = await SharedPreferences.getInstance();
    final rawJson = preferences.getString(_localAccountKey);
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      return StoredAccount.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocalAccount(StoredAccount account) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localAccountKey, jsonEncode(account.toJson()));
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.storage,
    required this.onAccountCreated,
    required this.onAccountImported,
  });

  final AccountStorage storage;
  final ValueChanged<StoredAccount> onAccountCreated;
  final ValueChanged<StoredAccount> onAccountImported;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _createPasswordController = TextEditingController();
  final TextEditingController _importPasswordController = TextEditingController();

  bool _creating = false;
  bool _importing = false;
  String? _importedFileName;
  String? _importError;
  StoredAccount? _pendingImportedAccount;
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _createPasswordController.dispose();
    _importPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAccountFile() async {
    setState(() {
      _importError = null;
      _pendingImportedAccount = null;
    });

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json', 'linkup'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    try {
      final content = utf8.decode(result.files.single.bytes!);
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final account = StoredAccount.fromJson(decoded);
      if (account.passwordHash.isEmpty) {
        throw const FormatException('Missing password hash');
      }

      setState(() {
        _importedFileName = result.files.single.name;
        _pendingImportedAccount = account;
      });
    } catch (_) {
      setState(() {
        _importedFileName = null;
        _pendingImportedAccount = null;
        _importError = 'That file is not a valid LinkUP account backup.';
      });
    }
  }

  Future<void> _createAccount() async {
    final password = _createPasswordController.text.trim();
    if (password.length < 4) {
      _showMessage('Set a password with at least 4 characters.');
      return;
    }

    setState(() {
      _creating = true;
    });

    final account = StoredAccount(
      name: _nameController.text.trim().isEmpty ? 'Anonymous LinkUP' : _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      passwordHash: widget.storage.hashPassword(password),
      createdAt: DateTime.now().toIso8601String(),
    );

    if (!mounted) {
      return;
    }

    widget.onAccountCreated(account);

    setState(() {
      _creating = false;
    });

    _showBackupDialog(account);
  }

  Future<void> _importAccount() async {
    final importedAccount = _pendingImportedAccount;
    if (importedAccount == null) {
      _showMessage('Load a LinkUP account file first.');
      return;
    }

    final passwordHash = widget.storage.hashPassword(
      _importPasswordController.text.trim(),
    );

    if (passwordHash != importedAccount.passwordHash) {
      _showMessage('Password mismatch. The file was loaded, but it cannot be unlocked.');
      return;
    }

    setState(() {
      _importing = true;
    });

    widget.onAccountImported(importedAccount);

    if (!mounted) {
      return;
    }

    setState(() {
      _importing = false;
    });
  }

  void _showBackupDialog(StoredAccount account) {
    final backupJson = const JsonEncoder.withIndent('  ').convert(account.toJson());

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Backup this account'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This prototype stores your account locally. Save the JSON below as a .linkup or .json file if you want to import it on another device later.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF151515)
                        : const Color(0xFFF4F6F8),
                  ),
                  child: SelectableText(backupJson),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(this.context);
                await Clipboard.setData(ClipboardData(text: backupJson));
                if (!mounted || !context.mounted) {
                  return;
                }
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Backup JSON copied to your clipboard.')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kVibrantRed),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToStep(int step) {
    setState(() {
      _step = step;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxWidth = _step == 0 ? 620.0 : 540.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [kTrueBlack, const Color(0xFF101720), const Color(0xFF180A0A)]
                : [Colors.white, const Color(0xFFF2F6FA), const Color(0xFFFFF1F0)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildStep(context, theme, isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, ThemeData theme, bool isDark) {
    switch (_step) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey('intro-step'),
          child: _GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LinkUP',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Peer-to-peer messaging with no full-time middleman. This first build focuses on the entry gate: import an account file or create a new local identity secured by password.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    height: 1.45,
                    color: isDark ? kSilver.withValues(alpha: 0.92) : kDarkGray,
                  ),
                ),
                const SizedBox(height: 28),
                const _SignalStrip(
                  label: 'Security',
                  value: 'Password gate with local account persistence',
                  color: kVibrantRed,
                ),
                const SizedBox(height: 12),
                const _SignalStrip(
                  label: 'Network',
                  value: 'Positioning server planned for peer discovery only',
                  color: kNavy,
                ),
                const SizedBox(height: 12),
                const _SignalStrip(
                  label: 'Current scope',
                  value: 'Onboarding, unlock flow, and messenger shell',
                  color: kLightNavy,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kVibrantRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onPressed: () => _goToStep(1),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey('choice-step'),
          child: _GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get started', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Choose one path. You can create a fresh local identity or unlock an existing LinkUP account file.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    color: isDark ? kSilver.withValues(alpha: 0.88) : kDarkGray,
                  ),
                ),
                const SizedBox(height: 24),
                _ActionChoiceButton(
                  title: 'Create a new account',
                  description: 'Set a password now. Name and real number stay optional.',
                  color: kVibrantRed,
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () => _goToStep(3),
                ),
                const SizedBox(height: 14),
                _ActionChoiceButton(
                  title: 'Load existing account',
                  description: 'Import your account file and unlock it with your password.',
                  color: kVibrantRed,
                  icon: Icons.upload_file_rounded,
                  onTap: () => _goToStep(2),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _goToStep(0),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        );
      case 2:
        return KeyedSubtree(
          key: const ValueKey('load-step'),
          child: _GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Load existing account', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'First-time on this device? Load your account file, then unlock it with your password.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? kSilver.withValues(alpha: 0.85) : kDarkGray,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _pickAccountFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(_importedFileName ?? 'Choose account file'),
                ),
                if (_importError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _importError!,
                    style: const TextStyle(color: kVibrantRed),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _importPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _goToStep(1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kVibrantRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _importing ? null : _importAccount,
                        child: Text(_importing ? 'Unlocking...' : 'Load and unlock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey('create-step'),
          child: _GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create new account', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'A password is required. Name and real number are optional for now.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? kSilver.withValues(alpha: 0.85) : kDarkGray,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Real number',
                    prefixIcon: Icon(Icons.call_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _createPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _goToStep(1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kVibrantRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _creating ? null : _createAccount,
                        child: Text(_creating ? 'Creating...' : 'Create account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.account,
    required this.onAuthenticated,
  });

  final StoredAccount account;
  final ValueChanged<StoredAccount> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final AccountStorage _storage = AccountStorage();
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() {
    setState(() {
      _submitting = true;
    });

    final passwordHash = _storage.hashPassword(_passwordController.text.trim());
    if (passwordHash != widget.account.passwordHash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong password.')),
      );
      setState(() {
        _submitting = false;
      });
      return;
    }

    widget.onAuthenticated(widget.account);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [kTrueBlack, const Color(0xFF121820)]
                : [Colors.white, const Color(0xFFF3F8FD)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? kNavy : const Color(0xFFE8EEF5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.account.initials,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? kSilver : kNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Welcome back to LinkUP', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      widget.account.name,
                      style: theme.textTheme.titleMedium?.copyWith(color: kVibrantRed),
                    ),
                    if (widget.account.phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(widget.account.phoneNumber),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      onSubmitted: (_) => _unlock(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.password_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kVibrantRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submitting ? null : _unlock,
                        child: Text(_submitting ? 'Checking...' : 'Unlock account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.account,
    required this.onLogout,
  });

  final StoredAccount account;
  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final List<_Contact> _contacts = [];

  Future<void> _openAddContactDialog() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add contact', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Use a contact key directly, import a QR payload, or share your own QR code.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _ContactActionTile(
                  title: 'Enter contact key',
                  subtitle: 'Paste a LinkUP contact key string.',
                  icon: Icons.key_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showManualContactDialog();
                  },
                ),
                const SizedBox(height: 12),
                _ContactActionTile(
                  title: 'Scan QR code',
                  subtitle: 'Desktop import: paste the QR payload or load it from clipboard.',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showQrImportDialog();
                  },
                ),
                const SizedBox(height: 12),
                _ContactActionTile(
                  title: 'Share my QR code',
                  subtitle: 'Show your personal LinkUP key as a QR code.',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showShareQrDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showManualContactDialog() async {
    final keyController = TextEditingController();
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Enter contact key'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contact key',
                    prefixIcon: Icon(Icons.vpn_key_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact name (optional)',
                    prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kVibrantRed),
              onPressed: () {
                final added = _addContactFromKey(
                  keyController.text,
                  customName: nameController.text,
                );
                if (added && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQrImportDialog() async {
    final payloadController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Scan QR code'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'On desktop, paste the QR payload here. If you copied it from another device, use Paste from clipboard first.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: payloadController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'QR payload',
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final clipboard = await Clipboard.getData('text/plain');
                if (!mounted) {
                  return;
                }
                payloadController.text = clipboard?.text ?? '';
              },
              child: const Text('Paste from clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kVibrantRed),
              onPressed: () {
                final added = _addContactFromKey(payloadController.text);
                if (added && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showShareQrDialog() async {
    final contactKey = widget.account.contactKey;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Share my QR code'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF151515)
                        : const Color(0xFFF4F6F8),
                  ),
                  child: QrImageView(
                    data: contactKey,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  contactKey,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: contactKey));
                if (!mounted || !context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Contact key copied to clipboard.')),
                );
              },
              child: const Text('Copy key'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kVibrantRed),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  bool _addContactFromKey(String rawKey, {String customName = ''}) {
    final normalizedKey = rawKey.trim();
    if (normalizedKey.isEmpty) {
      _showMessage('Enter a contact key first.');
      return false;
    }

    if (!normalizedKey.startsWith('linkup:')) {
      _showMessage('That is not a valid LinkUP contact key.');
      return false;
    }

    if (_contacts.any((contact) => contact.key == normalizedKey)) {
      _showMessage('That contact is already in your list.');
      return false;
    }

    final fallbackName = 'Contact ${_contacts.length + 1}';

    setState(() {
      _contacts.add(
        _Contact(
          name: customName.trim().isEmpty ? fallbackName : customName.trim(),
          key: normalizedKey,
        ),
      );
    });

    _showMessage('Contact added.');
    return true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _TopBar(account: widget.account, onLogout: widget.onLogout),
              const SizedBox(height: 16),
              Expanded(
                child: _ContactsPanel(
                  account: widget.account,
                  contacts: _contacts,
                  onAddContact: _openAddContactDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.account, required this.onLogout});

  final StoredAccount account;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'LinkUP',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kVibrantRed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              account.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onLogout,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF161616)
                  : const Color(0xFFF3F5F7),
            ),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Lock app',
          ),
        ],
      ),
    );
  }
}

class _ContactsPanel extends StatelessWidget {
  const _ContactsPanel({
    required this.account,
    required this.contacts,
    required this.onAddContact,
  });

  final StoredAccount account;
  final List<_Contact> contacts;
  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Contacts',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kVibrantRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onAddContact,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add contact'),
                ),
              ],
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No contacts yet.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isDark ? kSilver.withValues(alpha: 0.82) : kDarkGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Use Add contact to enter a key, scan a QR payload, or share your own QR code.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? kSilver.withValues(alpha: 0.76) : kDarkGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: onAddContact,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('Open contact tools'),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: isDark ? const Color(0xFF171717) : const Color(0xFFF4F6F8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Your contact key',
                                  style: theme.textTheme.labelLarge?.copyWith(color: kVibrantRed),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  account.contactKey,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = contacts[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {},
                        child: Ink(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? kDarkGray : const Color(0xFFE0E4EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.initials,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionChoiceButton extends StatelessWidget {
  const _ActionChoiceButton({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? kDarkGray : const Color(0xFFE0E4EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: kVibrantRed.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.add),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(icon, color: kVibrantRed),
          ],
        ),
      ),
    );
  }
}

class _SignalStrip extends StatelessWidget {
  const _SignalStrip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark ? const Color(0xFF101010) : Colors.white.withValues(alpha: 0.92),
        border: Border.all(
          color: isDark ? kDarkGray.withValues(alpha: 0.45) : const Color(0xFFE4E8ED),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.24) : const Color(0x140F1F2E),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Contact {
  const _Contact({required this.name, required this.key});

  final String name;
  final String key;

  String get initials {
    if (name.trim().isEmpty) {
      return 'LU';
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}