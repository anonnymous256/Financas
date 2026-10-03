import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/constants/icons.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dates.dart';
import '../core/utils/money.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: expenseColor));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: expenseColor) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<T?> showAppForm<T>(BuildContext context, {required Widget child}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 780),
          child: child,
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.92, child: child),
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scroll = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final padding = EdgeInsets.all(narrow ? 16 : 28);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (narrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              titleBlock,
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
      ],
    );
    if (scroll) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: 20), child],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const SizedBox(height: 20), Expanded(child: child)],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(caption, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Não foi possível carregar',
      message: message,
      action: OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        count,
        (index) => Container(
          height: 76,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.cents, {super.key, this.currency = 'BRL', this.style, this.signed = false});

  final int cents;
  final String currency;
  final TextStyle? style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final color = signed ? (cents >= 0 ? incomeColor : expenseColor) : null;
    final prefix = signed && cents > 0 ? '+' : '';
    return Text(
      '$prefix${formatMoney(cents, currency: currency)}',
      style: (style ?? const TextStyle(fontWeight: FontWeight.w800)).copyWith(color: color),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final color = paid ? incomeColor : warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}

class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onSubmit,
    this.loading = false,
    this.submitLabel = 'Salvar',
  });

  final String title;
  final Widget child;
  final VoidCallback? onSubmit;
  final bool loading;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : onSubmit,
                  child: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(submitLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const colors = [
      0xFF0F766E, 0xFF059669, 0xFF2563EB, 0xFF4F46E5, 0xFF7C3AED, 0xFFDB2777,
      0xFFE11D48, 0xFFEA580C, 0xFFD97706, 0xFFCA8A04, 0xFF0891B2, 0xFF475569,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final selected = color == value;
        return InkWell(
          onTap: () => onChanged(color),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
              boxShadow: selected ? [BoxShadow(color: Color(color).withValues(alpha: 0.5), blurRadius: 8)] : null,
            ),
            child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}

class IconPicker extends StatelessWidget {
  const IconPicker({super.key, required this.value, required this.onChanged, required this.color});

  final String value;
  final ValueChanged<String> onChanged;
  final int color;

  @override
  Widget build(BuildContext context) {
    const keys = [
      'payments', 'work', 'trending_up', 'storefront', 'restaurant', 'home', 'directions_car',
      'medical', 'school', 'sports', 'shopping_bag', 'subscriptions', 'receipt', 'account_balance',
      'savings', 'wallet', 'phone', 'credit_card', 'flag', 'flight', 'favorite', 'beach', 'devices',
      'bolt', 'gas', 'fitness', 'pets', 'more_horiz',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keys.map((key) {
        final selected = key == value;
        return InkWell(
          onTap: () => onChanged(key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? Color(color).withValues(alpha: 0.16) : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconFor(key), color: selected ? Color(color) : null, size: 20),
          ),
        );
      }).toList(),
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    locale: const Locale('pt', 'BR'),
  );
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await pickDate(context, value);
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(formatDay(value)),
      ),
    );
  }
}

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pages,
    required this.onPage,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    final start = (page - 2).clamp(1, pages);
    final end = (start + 4).clamp(1, pages);
    final numbers = <int>[for (var i = start; i <= end; i++) i];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          TextButton(onPressed: page > 1 ? () => onPage(page - 1) : null, child: const Text('Anterior')),
          ...numbers.map(
            (number) => number == page
                ? FilledButton(onPressed: () {}, child: Text('$number'))
                : TextButton(onPressed: () => onPage(number), child: Text('$number')),
          ),
          TextButton(onPressed: page < pages ? () => onPage(page + 1) : null, child: const Text('Próximo')),
        ],
      ),
    );
  }
}

class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.photoUrl, required this.name, this.radius = 22});

  final String photoUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoUrl.startsWith('data:image')) {
      final encoded = photoUrl.split(',').last;
      image = MemoryImage(base64Decode(encoded));
    } else if (photoUrl.startsWith('http')) {
      image = NetworkImage(photoUrl);
    }
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundImage: image,
      child: image == null ? Text(letter, style: const TextStyle(fontWeight: FontWeight.w800)) : null,
    );
  }
}
