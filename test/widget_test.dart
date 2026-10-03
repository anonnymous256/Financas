import 'package:financas/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata real brasileiro', () {
    expect(formatMoney(100), 'R\$ 1,00');
  });
}
