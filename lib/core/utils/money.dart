import 'app_exception.dart';

String formatMoney(int cents, {String currency = 'BRL'}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final fraction = (abs % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  final symbol = switch (currency) {
    'USD' => r'US$',
    'EUR' => '€',
    _ => r'R$',
  };
  return '${negative ? '-' : ''}$symbol $buffer,$fraction';
}

int parseMoney(String input, {bool allowZero = false}) {
  var text = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (text.isEmpty) {
    throw const AppException('Informe um valor.');
  }
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    text = text.replaceAll('.', '');
  }
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) {
    throw const AppException('Valor inválido.');
  }
  final cents = (value * 100).round();
  if (cents < 0) {
    throw const AppException('O valor não pode ser negativo.');
  }
  if (!allowZero && cents == 0) {
    throw const AppException('O valor deve ser maior que zero.');
  }
  if (cents > 100000000000) {
    throw const AppException('Valor muito alto.');
  }
  return cents;
}

int percentChange(int current, int previous) {
  if (previous == 0) return current == 0 ? 0 : 100;
  return (((current - previous) / previous) * 100).round();
}

List<int> splitCents(int total, int parts) {
  if (parts <= 0) {
    throw const AppException('Informe um parcelamento válido.');
  }
  final base = total ~/ parts;
  final remainder = total - (base * parts);
  return List<int>.generate(parts, (index) {
    return index == parts - 1 ? base + remainder : base;
  });
}
