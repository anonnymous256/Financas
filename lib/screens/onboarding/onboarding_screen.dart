import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/defaults.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';
import '../../widgets/finance_forms.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _balance = TextEditingController(text: '0');
  final _cardName = TextEditingController();
  final _cardLimit = TextEditingController();
  final _lastFour = TextEditingController();
  var _step = 0;
  var _type = 'checking';
  var _skipCard = true;
  var _loading = false;
  String? _accountId;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _bank.dispose();
    _balance.dispose();
    _cardName.dispose();
    _cardLimit.dispose();
    _lastFour.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skip = false}) async {
    setState(() => _loading = true);
    try {
      await ref.read(financeActionsProvider).run((bundle) {
        if (!skip && _accountId == null && _name.text.trim().isNotEmpty) {
          final account = BankAccount(
            id: newId(),
            userId: bundle.profile.userId,
            name: _name.text.trim(),
            bank: _bank.text.trim(),
            type: _type,
            initialBalanceCents: parseMoney(_balance.text, allowZero: true),
            balanceCents: 0,
            color: 0xFF0F766E,
            icon: 'account_balance',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          FinanceEngine.upsertAccount(bundle, account);
          _accountId = account.id;
        }
        if (!skip && !_skipCard && _cardName.text.trim().isNotEmpty) {
          FinanceEngine.upsertCard(
            bundle,
            CreditCardAccount(
              id: newId(),
              userId: bundle.profile.userId,
              name: _cardName.text.trim(),
              bank: _bank.text.trim(),
              brand: 'Visa',
              limitCents: parseMoney(_cardLimit.text),
              closingDay: 1,
              dueDay: 10,
              color: 0xFF4F46E5,
              lastFour: _lastFour.text.trim(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        FinanceEngine.completeOnboarding(bundle);
      });
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    if (_step == 1 && _name.text.trim().isEmpty) {
      showError(context, 'Informe o nome da primeira conta.');
      return;
    }
    if (_step == 2) {
      try {
        parseMoney(_balance.text, allowZero: true);
      } on AppException catch (error) {
        showError(context, error.message);
        return;
      }
    }
    if (_step == 3 && !_skipCard) {
      if (_cardName.text.trim().isEmpty || !RegExp(r'^\d{4}$').hasMatch(_lastFour.text.trim())) {
        showError(context, 'Informe o nome do cartão e os 4 últimos dígitos, ou pule esta etapa.');
        return;
      }
    }
    if (_step == 5) {
      _finish();
      return;
    }
    setState(() => _step += 1);
    _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <FinanceCategory>[];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: List.generate(6, (index) {
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index <= _step ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step(
                          title: 'Vamos configurar sua vida financeira.',
                          body: 'Em poucos passos você cadastra a primeira conta, o saldo e, se quiser, um cartão.',
                        ),
                        _Step(
                          title: 'Qual é a sua primeira conta?',
                          child: Column(
                            children: [
                              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome da conta')),
                              const SizedBox(height: 12),
                              TextField(controller: _bank, decoration: const InputDecoration(labelText: 'Banco')),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _type,
                                decoration: const InputDecoration(labelText: 'Tipo'),
                                items: accountTypeLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                                onChanged: (value) => setState(() => _type = value ?? _type),
                              ),
                            ],
                          ),
                        ),
                        _Step(
                          title: 'Qual o saldo atual?',
                          body: 'Use o valor que existe hoje. As próximas movimentações atualizam esse saldo.',
                          child: TextField(controller: _balance, decoration: const InputDecoration(labelText: 'Saldo atual', prefixText: 'R\$ '), keyboardType: TextInputType.number),
                        ),
                        _Step(
                          title: 'Você tem um cartão?',
                          body: 'Pode pular e cadastrar depois. O número completo nunca é armazenado.',
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Não tenho cartão agora'),
                                value: _skipCard,
                                onChanged: (value) => setState(() => _skipCard = value),
                              ),
                              if (!_skipCard) ...[
                                TextField(controller: _cardName, decoration: const InputDecoration(labelText: 'Nome do cartão')),
                                const SizedBox(height: 12),
                                TextField(controller: _cardLimit, decoration: const InputDecoration(labelText: 'Limite', prefixText: 'R\$ ')),
                                const SizedBox(height: 12),
                                TextField(controller: _lastFour, decoration: const InputDecoration(labelText: 'Últimos 4 dígitos'), maxLength: 4),
                              ],
                            ],
                          ),
                        ),
                        _Step(
                          title: 'Suas categorias',
                          body: 'Já deixamos as categorias mais usadas prontas. Você pode criar outras agora.',
                          child: Column(
                            children: [
                              ...categories.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item.name), subtitle: Text(item.kind == 'income' ? 'Receita' : 'Despesa'))),
                              OutlinedButton(onPressed: () => showCategoryForm(context), child: const Text('Criar categoria')),
                            ],
                          ),
                        ),
                        const _Step(
                          title: 'Tudo pronto.',
                          body: 'Seu painel já pode receber a primeira receita ou despesa.',
                        ),
                      ],
                    ),
                  ),
                  OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: _loading ? null : () => _finish(skip: true), child: const Text('Pular por agora')),
                      FilledButton(onPressed: _loading ? null : _next, child: Text(_step == 5 ? 'Ir para o painel' : 'Continuar')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, this.body, this.child});

  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(body!, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        if (child != null) ...[const SizedBox(height: 24), child!],
      ],
    );
  }
}
