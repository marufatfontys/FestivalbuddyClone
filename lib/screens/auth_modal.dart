import 'package:flutter/material.dart';
import '../services/app_state.dart';

class AuthModalSheet extends StatefulWidget {
  const AuthModalSheet({
    super.key,
    required this.appState,
    this.initialTab = 0,
  });

  final AppState appState;
  final int initialTab;

  static Future<void> show(
    BuildContext context,
    AppState appState, {
    int initialTab = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AuthModalSheet(
        appState: appState,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends State<AuthModalSheet> {
  late int _mode; // 0 = Sign In, 1 = Sign Up, 2 = Password Reset
  final _emailController = TextEditingController(text: 'visitor@fontys.nl');
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController(text: 'EcoPassword2027!');
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _acceptedPrivacyPolicy = false;
  bool _simulateNewDeviceAlert = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialTab;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: Color(0xFF1B5E20)),
            SizedBox(width: 8),
            Expanded(child: Text('Festival Buddy Privacy Policy')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. What Data Is Collected (Data Minimization)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Account email address & display name\n'
                '• Argon2id salted password hash (never plain text)\n'
                '• Purchased ticket IDs & optional music/SDG preference tags\n'
                '• On-site tent/car/bike pins are stored locally on your phone.',
              ),
              SizedBox(height: 12),
              Text(
                '2. Why It Is Collected',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• To bind festival tickets securely to your account\n'
                '• To recommend relevant sustainable festivals\n'
                '• To alert you if a login occurs from an unrecognized device.',
              ),
              SizedBox(height: 12),
              Text(
                '3. Storage Duration & Backup Policy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Encrypted via TLS 1.3 in transit.\n'
                '• Daily encrypted backups retained for 30 days (restoration tested monthly).',
              ),
              SizedBox(height: 12),
              Text(
                '4. Your GDPR Rights (Accessible in ≤3 Clicks)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Right to View, Export (JSON), and Request Erasure/Deletion of your personal data at any time from the Profile tab.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _acceptedPrivacyPolicy = true);
              Navigator.pop(ctx);
            },
            child: const Text('Accept Policy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Account & Security Gateway',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Browsing festivals & emergency maps never requires an account. Sign in only for Tickets, Reporting, or Organizer tools.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Sign In'),
                  icon: Icon(Icons.login_rounded, size: 18),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Sign Up'),
                  icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Reset 24h'),
                  icon: Icon(Icons.lock_reset_rounded, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_successMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_mode == 0) _buildSignInForm(context),
            if (_mode == 1) _buildSignUpForm(context),
            if (_mode == 2) _buildPasswordResetForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Fill Demo Accounts:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person, size: 16),
              label: const Text('Visitor'),
              onPressed: () {
                setState(() {
                  _emailController.text = 'visitor@fontys.nl';
                  _passwordController.text = 'EcoPassword2027!';
                });
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.festival, size: 16),
              label: const Text('Organizer'),
              onPressed: () {
                setState(() {
                  _emailController.text = 'organizer@greenpulse.nl';
                  _passwordController.text = 'OrgSecure2027!';
                });
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.admin_panel_settings, size: 16),
              label: const Text('Admin'),
              onPressed: () {
                setState(() {
                  _emailController.text = 'admin@festivalbuddy.nl';
                  _passwordController.text = 'AdminVault2027!';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password (Argon2id verified)',
            prefixIcon: Icon(Icons.lock_outline_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _simulateNewDeviceAlert,
          onChanged: (val) =>
              setState(() => _simulateNewDeviceAlert = val ?? false),
          title: const Text(
            'Simulate login from a new device (triggers <5 min email alert)',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final err = widget.appState.login(
                email: _emailController.text,
                password: _passwordController.text,
                isNewDeviceLogin: _simulateNewDeviceAlert,
              );
              if (err != null) {
                setState(() => _errorMessage = err);
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.lock_open_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Sign In Securely (HTTPS/TLS)'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(BuildContext context) {
    final pwd = _passwordController.text;
    final isStrong = pwd.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Unique Email Address',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Create Password (min 8 chars)',
            prefixIcon: const Icon(Icons.key_rounded),
            border: const OutlineInputBorder(),
            helperText: isStrong
                ? 'Strong password • Will be hashed with Argon2id + unique salt'
                : 'Use 8+ chars with uppercase & number',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _acceptedPrivacyPolicy,
                    onChanged: (v) =>
                        setState(() => _acceptedPrivacyPolicy = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showPrivacyPolicyDialog,
                      child: const Text.rich(
                        TextSpan(
                          text: 'I have read and accept the ',
                          children: [
                            TextSpan(
                              text: 'Privacy Policy & GDPR Notice',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' (Required before account creation).'),
                          ],
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showPrivacyPolicyDialog,
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Read Full Privacy Policy'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final err = widget.appState.registerAccount(
                email: _emailController.text,
                name: _nameController.text.isEmpty
                    ? 'Festival Visitor'
                    : _nameController.text,
                password: _passwordController.text,
                acceptedPrivacyPolicy: _acceptedPrivacyPolicy,
              );
              if (err != null) {
                setState(() => _errorMessage = err);
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.verified_user_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Create Account with Argon2id Hashing'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordResetForm(BuildContext context) {
    final activeToken = widget.appState.latestResetToken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Single-Use 24-Hour Password Reset Link (Invalidates all active sessions upon reset):',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Account Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                final token = widget.appState
                    .requestPasswordResetLink(_emailController.text);
                setState(() {
                  _resetTokenController.text = token.token;
                  _errorMessage = null;
                  _successMessage =
                      'Single-use reset link sent! Expires in 24h: ${token.token}';
                });
              },
              child: const Text('Send 24h Link'),
            ),
          ],
        ),
        if (activeToken != null) ...[
          const SizedBox(height: 8),
          Text(
            'Active Token: ${activeToken.token} • Used: ${activeToken.isUsed}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _resetTokenController,
          decoration: const InputDecoration(
            labelText: 'Single-Use Token from Email',
            prefixIcon: Icon(Icons.token_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password (min 8 chars)',
            prefixIcon: Icon(Icons.lock_reset_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final err = widget.appState.completePasswordReset(
                tokenString: _resetTokenController.text,
                newPassword: _newPasswordController.text,
              );
              if (err != null) {
                setState(() {
                  _errorMessage = err;
                  _successMessage = null;
                });
              } else {
                setState(() {
                  _errorMessage = null;
                  _successMessage =
                      'Password reset complete! Token is now burned and all active sessions were invalidated.';
                });
              }
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Complete Reset & Invalidate Sessions'),
            ),
          ),
        ),
      ],
    );
  }
}
