import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final auth = ref.read(authStateProvider);
    if (auth.isLoading) return;
    final uid = auth.value;
    if (uid == null) return;
    if (ref.read(profileProvider).value != null) return;
    try {
      final repository = ref.read(authRepositoryProvider);
      await ref.read(financeRepositoryProvider).ensureUser(
            uid,
            name: repository.currentName ?? 'Usuário',
            email: repository.currentEmail ?? '',
          );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: ErrorState(message: _error!, onRetry: _prepare));
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 32),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionControllerProvider).signIn(email: _email.text, password: _password.text);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BrandMark(title: 'Entrar', subtitle: 'Acompanhe sua vida financeira em um só lugar.'),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Senha',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Informe a senha.' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('Esqueci minha senha')),
            ),
            FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Entrando...' : 'Entrar')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.go('/register'), child: const Text('Criar conta')),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionControllerProvider).signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BrandMark(title: 'Criar conta', subtitle: 'Seus dados ficam separados dos demais usuários.'),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome completo'), validator: validateName),
            const SizedBox(height: 12),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'), validator: validateEmail),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Senha',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
              validator: (value) => validatePasswordConfirmation(value, _password.text),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Criando...' : 'Criar conta')),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Já tenho uma conta')),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _demoCode;
  var _sent = false;
  var _loading = false;
  var _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final error = validateEmail(_email.text);
    if (error != null) {
      showError(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      final code = await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      setState(() {
        _sent = true;
        _demoCode = code;
        if (code != null) _code.text = code;
      });
      if (mounted) {
        showSuccess(
          context,
          code == null
              ? 'Enviamos um link de recuperação para o seu e-mail.'
              : 'Modo demonstração: use o código exibido para definir a nova senha.',
        );
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final error = validatePassword(_password.text);
    if (error != null) {
      showError(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(
            email: _email.text,
            code: _code.text,
            newPassword: _password.text,
          );
      if (mounted) {
        showSuccess(context, 'Senha alterada. Entre com a nova senha.');
        context.go('/login');
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localReset = !ref.watch(authRepositoryProvider).sendsResetEmail;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandMark(title: 'Recuperar senha', subtitle: 'Vamos te ajudar a voltar para a sua conta.'),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'), validator: validateEmail),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loading ? null : _send, child: const Text('Enviar recuperação')),
          if (_sent && localReset) ...[
            const SizedBox(height: 16),
            if (_demoCode != null)
              Text('Código de demonstração: $_demoCode', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código')),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loading ? null : _confirm, child: const Text('Definir nova senha')),
          ],
          TextButton(onPressed: () => context.go('/login'), child: const Text('Voltar ao login')),
        ],
      ),
    );
  }
}
