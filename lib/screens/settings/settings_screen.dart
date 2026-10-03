import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _minimum = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  var _ready = false;

  @override
  void dispose() {
    _minimum.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save(UserProfile profile) async {
    try {
      final minimum = parseMoney(_minimum.text.isEmpty ? '0' : _minimum.text, allowZero: true);
      await ref.read(financeActionsProvider).run((bundle) {
        FinanceEngine.updateProfile(
          bundle,
          profile.copyWith(minimumBalanceCents: minimum),
        );
        FinanceEngine.refreshNotifications(bundle);
      });
      if (mounted) showSuccess(context, 'Configurações salvas.');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _changePassword() async {
    try {
      await ref.read(authRepositoryProvider).updatePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) showSuccess(context, 'Senha alterada.');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final cloud = ref.watch(firebaseReadyProvider);
    if (profile != null && !_ready) {
      _minimum.text = (profile.minimumBalanceCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _ready = true;
    }
    if (profile == null) return const PageFrame(title: 'Configurações', child: SkeletonList());
    return PageFrame(
      title: 'Configurações',
      subtitle: 'Conta, preferências financeiras e aparência.',
      actions: [FilledButton(onPressed: () => _save(profile), child: const Text('Salvar'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!cloud) const _CloudCard(),
          _section(context, 'Conta', [
            ListTile(title: const Text('Nome'), subtitle: Text(profile.name)),
            ListTile(title: const Text('E-mail'), subtitle: Text(profile.email)),
            TextField(controller: _currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Senha atual')),
            const SizedBox(height: 12),
            TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Nova senha')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _changePassword, child: const Text('Alterar senha')),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Financeiro', [
            DropdownButtonFormField<String>(
              initialValue: profile.currency,
              decoration: const InputDecoration(labelText: 'Moeda'),
              items: const [
                DropdownMenuItem(value: 'BRL', child: Text('Real (BRL)')),
                DropdownMenuItem(value: 'USD', child: Text('Dólar (USD)')),
                DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
              ],
              onChanged: (value) => _save(profile.copyWith(currency: value ?? 'BRL')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: profile.financialMonthStartDay.clamp(1, 28),
              decoration: const InputDecoration(labelText: 'Primeiro dia do mês financeiro'),
              items: [for (var day = 1; day <= 28; day++) DropdownMenuItem(value: day, child: Text('Dia $day'))],
              onChanged: (value) => _save(profile.copyWith(financialMonthStartDay: value ?? 1)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minimum,
              decoration: const InputDecoration(labelText: 'Saldo mínimo', prefixText: 'R\$ '),
              keyboardType: TextInputType.number,
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Aparência', [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: 'dark', label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
                ButtonSegment(value: 'system', label: Text('Automático'), icon: Icon(Icons.brightness_auto)),
              ],
              selected: {profile.themeMode},
              onSelectionChanged: (value) => _save(profile.copyWith(themeMode: value.first)),
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Notificações', [
            SwitchListTile(title: const Text('Faturas'), value: profile.notifyInvoices, onChanged: (value) => _save(profile.copyWith(notifyInvoices: value))),
            SwitchListTile(title: const Text('Contas'), value: profile.notifyBills, onChanged: (value) => _save(profile.copyWith(notifyBills: value))),
            SwitchListTile(title: const Text('Saldo baixo'), value: profile.notifyLowBalance, onChanged: (value) => _save(profile.copyWith(notifyLowBalance: value))),
            SwitchListTile(title: const Text('Metas'), value: profile.notifyGoals, onChanged: (value) => _save(profile.copyWith(notifyGoals: value))),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Firebase ainda não está configurado', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Os dados ficam neste aparelho, isolados por usuário. Para usar a nuvem:'),
            SizedBox(height: 8),
            Text('1. Crie um projeto no Firebase e ative Authentication por e-mail e o Firestore.'),
            Text('2. Rode flutterfire configure na pasta do projeto.'),
            Text('3. Publique firestore.rules.'),
          ],
        ),
      ),
    );
  }
}
