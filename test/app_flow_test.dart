import 'package:financas/main.dart';
import 'package:financas/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cadastro, onboarding e painel isolam a sessão', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          prefsProvider.overrideWithValue(preferences),
        ],
        child: const FinancasApp(),
      ),
    );

    await _until(tester, find.text('Entrar'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
    await tester.pump();
    await _until(tester, find.text('Nome completo'));

    final registerFields = _fieldsOf(find.text('Nome completo'));
    await tester.enterText(registerFields.at(0), 'Ana Silva');
    await tester.enterText(registerFields.at(1), 'ana@teste.com');
    await tester.enterText(registerFields.at(2), '123456');
    await tester.enterText(registerFields.at(3), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pump();
    await _until(tester, find.text('Vamos configurar sua vida financeira.'));

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Nubank');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir para o painel'));
    await tester.pump();
    await _until(tester, find.textContaining('Olá, Ana'));
    expect(find.text('Saldo total'), findsOneWidget);

    await tester.tap(find.text('Nova despesa'));
    await tester.pumpAndSettle();
    final expenseFields = _fieldsOf(find.text('Descrição'));
    await tester.enterText(expenseFields.at(0), 'Mercado');
    await tester.enterText(expenseFields.at(1), '50,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    await _until(tester, find.text('Mercado'));

    await tester.tap(find.text('Sair'));
    await tester.pump();
    await _until(tester, find.text('Entrar'));

    final loginFields = _fieldsOf(find.text('Acompanhe sua vida financeira em um só lugar.'));
    await tester.enterText(loginFields.at(0), 'bruno@teste.com');
    await tester.enterText(loginFields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();
    await _until(tester, find.text('Não encontramos uma conta com esse e-mail.'));
  });

  testWidgets('transações no celular abrem o filtro em um botão', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          prefsProvider.overrideWithValue(preferences),
        ],
        child: const FinancasApp(),
      ),
    );

    await _until(tester, find.text('Entrar'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
    await tester.pump();
    await _until(tester, find.text('Nome completo'));

    final registerFields = _fieldsOf(find.text('Nome completo'));
    await tester.enterText(registerFields.at(0), 'Ana Silva');
    await tester.enterText(registerFields.at(1), 'ana.mobile@teste.com');
    await tester.enterText(registerFields.at(2), '123456');
    await tester.enterText(registerFields.at(3), '123456');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pump();
    await _until(tester, find.text('Vamos configurar sua vida financeira.'));

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Nubank');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir para o painel'));
    await tester.pump();
    await _until(tester, find.textContaining('Olá, Ana'));

    await tester.tap(find.text('Movimentos'));
    await tester.pump();
    await _until(tester, find.text('Filtrar'));
    expect(find.text('Buscar descrição'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);
    expect(find.text('Buscar descrição'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _fieldsOf(Finder anchor) {
  final form = find.ancestor(of: anchor, matching: find.byType(Form));
  return find.descendant(of: form, matching: find.byType(TextFormField));
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).whereType<String>().join(' | ');
  fail('Não encontrou o elemento esperado. Textos: $texts');
}
