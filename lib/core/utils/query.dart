import '../../models/models.dart';
import '../../services/finance_engine.dart';

TxPage paginateTransactions(
  List<FinanceTransaction> source,
  TxFilter filter, {
  bool truncated = false,
}) {
  final search = filter.search.trim().toLowerCase();
  final filtered = source.where((transaction) {
    if (filter.kind == null && transaction.kind == TxKind.invoicePayment) return false;
    if (filter.kind != null && transaction.kind != filter.kind) return false;
    if (filter.status != null && filter.status!.isNotEmpty && transaction.status != filter.status) {
      return false;
    }
    if (filter.categoryId != null && filter.categoryId!.isNotEmpty && transaction.categoryId != filter.categoryId) {
      return false;
    }
    if (filter.accountId != null && filter.accountId!.isNotEmpty && transaction.accountId != filter.accountId) {
      return false;
    }
    if (filter.cardId != null && filter.cardId!.isNotEmpty && transaction.cardId != filter.cardId) {
      return false;
    }
    if (filter.from != null && transaction.date.isBefore(filter.from!)) return false;
    if (filter.to != null && transaction.date.isAfter(filter.to!)) return false;
    if (search.isNotEmpty &&
        !transaction.description.toLowerCase().contains(search) &&
        !transaction.notes.toLowerCase().contains(search)) {
      return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final start = (filter.page <= 1 ? 0 : (filter.page - 1) * filter.pageSize);
  final items = start >= filtered.length
      ? <FinanceTransaction>[]
      : filtered.skip(start).take(filter.pageSize).toList();
  return TxPage(
    items: items,
    total: filtered.length,
    page: filter.page < 1 ? 1 : filter.page,
    pageSize: filter.pageSize,
    truncated: truncated,
  );
}
