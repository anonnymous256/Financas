import 'dart:convert';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants/icons.dart';
import '../core/utils/dates.dart';
import '../core/utils/file_download.dart';
import '../core/utils/money.dart';
import '../models/models.dart';

class ReportData {
  const ReportData({
    required this.transactions,
    required this.incomeCents,
    required this.expenseCents,
  });

  final List<FinanceTransaction> transactions;
  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;
}

ReportData buildReport(List<FinanceTransaction> transactions) {
  var income = 0;
  var expense = 0;
  for (final transaction in transactions) {
    if (transaction.kind == 'income') income += transaction.amountCents;
    if (transaction.kind == 'expense' || transaction.kind == 'cardInstallment') {
      expense += transaction.amountCents;
    }
  }
  return ReportData(transactions: transactions, incomeCents: income, expenseCents: expense);
}

Future<void> exportReportPdf({
  required ReportData report,
  required String currency,
  required List<FinanceCategory> categories,
}) async {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Relatório financeiro', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Receitas: ${formatMoney(report.incomeCents, currency: currency)}'),
        pw.Text('Despesas: ${formatMoney(report.expenseCents, currency: currency)}'),
        pw.Text('Saldo: ${formatMoney(report.balanceCents, currency: currency)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Data', 'Tipo', 'Descrição', 'Categoria', 'Valor', 'Status'],
          data: report.transactions
              .map(
                (item) => [
                  formatDay(item.date),
                  kindLabel(item.kind),
                  item.description,
                  categories.where((category) => category.id == item.categoryId).map((category) => category.name).firstOrNull ?? '',
                  formatMoney(item.amountCents, currency: currency),
                  statusLabel(item.status),
                ],
              )
              .toList(),
        ),
      ],
    ),
  );
  await Printing.sharePdf(bytes: await document.save(), filename: 'relatorio-financeiro.pdf');
}

Future<String> exportReportCsv({
  required ReportData report,
  required String currency,
  required List<FinanceCategory> categories,
  required List<BankAccount> accounts,
  required List<CreditCardAccount> cards,
}) {
  final buffer = StringBuffer()..writeln('Data;Tipo;Descrição;Categoria;Conta;Cartão;Valor;Status;Observação');
  for (final item in report.transactions) {
    final category = categories.where((entry) => entry.id == item.categoryId).map((entry) => entry.name).firstOrNull ?? '';
    final account = accounts.where((entry) => entry.id == item.accountId).map((entry) => entry.name).firstOrNull ?? '';
    final card = cards.where((entry) => entry.id == item.cardId).map((entry) => entry.name).firstOrNull ?? '';
    buffer.writeln(
      [
        formatDay(item.date),
        kindLabel(item.kind),
        _csv(item.description),
        _csv(category),
        _csv(account),
        _csv(card),
        formatMoney(item.amountCents, currency: currency),
        statusLabel(item.status),
        _csv(item.notes),
      ].join(';'),
    );
  }
  return downloadBytes('relatorio-financeiro.csv', utf8.encode(buffer.toString()), 'text/csv');
}

String _csv(String value) => '"${value.replaceAll('"', '""')}"';

extension _FirstExport<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
