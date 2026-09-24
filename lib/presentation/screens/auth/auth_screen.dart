import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/search_repository.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';

class AuthScreen extends StatefulWidget {
  final BooruSource source;
  const AuthScreen({super.key, required this.source});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameCtrl = TextEditingController();
  final _credCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final repo = context.read<LocalRepository>();
    final creds = await repo.loadCredentials();
    final sourceCreds = creds[widget.source.name];
    if (sourceCreds != null) {
      setState(() {
        _usernameCtrl.text = sourceCreds['username'] ?? '';
        _loggedIn = true;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _credCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final credential = _credCtrl.text.trim();
    if (username.isEmpty || credential.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final searchRepo = context.read<SearchRepository>();
      final success = await searchRepo.login(widget.source, username, credential);
      if (success) {
        // Save credentials
        final localRepo = context.read<LocalRepository>();
        final existing = await localRepo.loadCredentials();
        existing[widget.source.name] = {
          'username': username,
          'credential': credential,
        };
        await localRepo.saveCredentials(existing);
        HapticFeedback.mediumImpact();
        setState(() {
          _loggedIn = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Login failed. Check your credentials.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final localRepo = context.read<LocalRepository>();
    final existing = await localRepo.loadCredentials();
    existing.remove(widget.source.name);
    await localRepo.saveCredentials(existing);
    setState(() {
      _loggedIn = false;
      _usernameCtrl.clear();
      _credCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.source;

    return Scaffold(
      appBar: AppBar(
        title: Text(source.domain),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Source Header ───────────────────────────────────────────────
            _SourceHeader(source: source),
            const SizedBox(height: 32),

            if (_loggedIn) ...[
              // ─── Logged In State ─────────────────────────────────────────
              _LoggedInCard(
                username: _usernameCtrl.text,
                source: source,
                onLogout: _logout,
              ),
            ] else ...[
              // ─── Login Form ───────────────────────────────────────────────
              _AuthInstructions(source: source),
              const SizedBox(height: 24),

              Text(
                source == BooruSource.rule34xxx ||
                        source == BooruSource.gelbooru
                    ? 'User ID'
                    : 'Username',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  hintText: source == BooruSource.rule34xxx ||
                          source == BooruSource.gelbooru
                      ? 'Your numeric user ID'
                      : 'Your username',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
                keyboardType: source == BooruSource.rule34xxx ||
                        source == BooruSource.gelbooru
                    ? TextInputType.number
                    : TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              Text(
                'API Key',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _credCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Your API key',
                  prefixIcon:
                      const Icon(Icons.key_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                autocorrect: false,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Connect Account'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceHeader extends StatelessWidget {
  final BooruSource source;
  const _SourceHeader({required this.source});

  Color get _color {
    switch (source) {
      case BooruSource.rule34xxx:
        return AppColors.primary;
      case BooruSource.e621:
        return AppColors.secondary;
      case BooruSource.gelbooru:
        return const Color(0xFFFF7CA0);
      case BooruSource.paheal:
        return const Color(0xFFFFCC7C);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              source.shortName,
              style: TextStyle(
                color: _color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source.domain, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                source == BooruSource.rule34xxx
                    ? 'API credentials are required to search Rule34.xxx.'
                    : source == BooruSource.gelbooru
                        ? 'Gelbooru may require API credentials for search access.'
                        : source == BooruSource.paheal
                            ? 'Paheal search works without an account.'
                            : 'Connect for higher limits and account features.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthInstructions extends StatelessWidget {
  final BooruSource source;
  const _AuthInstructions({required this.source});

  String get _instructions {
    switch (source) {
      case BooruSource.rule34xxx:
        return 'Go to rule34.xxx → My Account → Options → API Access Credentials. Copy your User ID and API key.';
      case BooruSource.e621:
        return 'Go to e621.net → Account → Manage API Access → Generate Key. Enter your username and the generated API key.';
      case BooruSource.gelbooru:
        return 'Go to gelbooru.com → My Account → API. Your User ID and API Key are shown there.';
      case BooruSource.paheal:
        return 'Paheal does not require authentication. Anonymous access provides full functionality.';
      default:
        return 'Enter your account credentials for this source.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _instructions,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedInCard extends StatelessWidget {
  final String username;
  final BooruSource source;
  final VoidCallback onLogout;

  const _LoggedInCard({
    required this.username,
    required this.source,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('Connected', style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.success,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text('Logged in as: $username', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Higher rate limits and account features are enabled',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Disconnect Account'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
