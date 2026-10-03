import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/validators.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _ready = false;
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;
    final nameError = validateName(_name.text);
    if (nameError != null) {
      showError(context, nameError);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(financeActionsProvider).run((bundle) {
        FinanceEngine.updateProfile(bundle, profile.copyWith(name: _name.text.trim(), phone: _phone.text.trim()));
      });
      if (mounted) showSuccess(context, 'Perfil atualizado.');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _photo() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final uid = ref.read(authStateProvider).value;
      if (uid == null) return;
      final url = await _storePhoto(bytes);
      final profile = ref.read(profileProvider).value;
      if (profile == null) return;
      await ref.read(financeActionsProvider).run((bundle) {
        FinanceEngine.updateProfile(bundle, profile.copyWith(photoUrl: url));
      });
      if (mounted) showSuccess(context, 'Foto atualizada.');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<String> _storePhoto(Uint8List bytes) async {
    if (bytes.length > 180000) {
      throw const AppException('Escolha uma imagem de até 180 KB.');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _changeEmail() async {
    final error = validateEmail(_email.text);
    if (error != null) {
      showError(context, error);
      return;
    }
    try {
      await ref.read(authRepositoryProvider).updateEmail(currentPassword: _password.text, newEmail: _email.text);
      if (!ref.read(firebaseReadyProvider)) {
        await ref.read(financeActionsProvider).run((bundle) => FinanceEngine.changeEmail(bundle, _email.text.trim().toLowerCase()));
      }
      if (mounted) {
        showSuccess(
          context,
          ref.read(firebaseReadyProvider)
              ? 'Enviamos um link de confirmação para o novo e-mail.'
              : 'E-mail atualizado.',
        );
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    if (profile != null && !_ready) {
      _name.text = profile.name;
      _phone.text = profile.phone;
      _email.text = profile.email;
      _ready = true;
    }
    if (profile == null) return const PageFrame(title: 'Meu perfil', child: SkeletonList());
    return PageFrame(
      title: 'Meu perfil',
      subtitle: 'Conta criada em ${formatDay(profile.createdAt)}.',
      actions: [
        FilledButton(onPressed: _loading ? null : _save, child: const Text('Salvar')),
        OutlinedButton(onPressed: () => ref.read(sessionControllerProvider).signOut(), child: const Text('Sair da conta')),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarView(photoUrl: profile.photoUrl, name: profile.name, radius: 36),
              const SizedBox(width: 16),
              OutlinedButton(onPressed: _photo, child: const Text('Alterar foto')),
            ],
          ),
          const SizedBox(height: 20),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefone'), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha atual para alterar o e-mail')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _changeEmail, child: const Text('Alterar e-mail')),
          if (profile.admin) ...[
            const SizedBox(height: 16),
            const Text('Esta conta está marcada como administradora. O painel administrativo fica para uma próxima etapa.'),
          ],
        ],
      ),
    );
  }
}
