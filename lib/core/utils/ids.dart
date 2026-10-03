import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

String fingerprintOf({
  required String kind,
  required String description,
  required int amountCents,
  required DateTime date,
  String? accountId,
  String? cardId,
  String? categoryId,
}) {
  final day = '${date.year}-${date.month}-${date.day}';
  return '$kind|${description.trim().toLowerCase()}|$amountCents|$day|'
      '${accountId ?? ''}|${cardId ?? ''}|${categoryId ?? ''}';
}
