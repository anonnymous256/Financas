import 'package:flutter/material.dart';

IconData iconFor(String key) {
  return switch (key) {
    'payments' => Icons.payments_outlined,
    'work' => Icons.work_outline,
    'trending_up' => Icons.trending_up,
    'storefront' => Icons.storefront_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'home' => Icons.home_outlined,
    'directions_car' => Icons.directions_car_outlined,
    'medical' => Icons.medical_services_outlined,
    'school' => Icons.school_outlined,
    'sports' => Icons.sports_esports_outlined,
    'shopping_bag' => Icons.shopping_bag_outlined,
    'subscriptions' => Icons.subscriptions_outlined,
    'receipt' => Icons.receipt_long_outlined,
    'account_balance' => Icons.account_balance_outlined,
    'more_horiz' => Icons.more_horiz,
    'savings' => Icons.savings_outlined,
    'wallet' => Icons.account_balance_wallet_outlined,
    'phone' => Icons.phone_iphone,
    'credit_card' => Icons.credit_card,
    'flag' => Icons.flag_outlined,
    'flight' => Icons.flight_outlined,
    'favorite' => Icons.favorite_outline,
    'beach' => Icons.beach_access_outlined,
    'devices' => Icons.devices_outlined,
    'bolt' => Icons.bolt_outlined,
    'gas' => Icons.local_gas_station_outlined,
    'fitness' => Icons.fitness_center,
    'pets' => Icons.pets_outlined,
    _ => Icons.circle_outlined,
  };
}

String kindLabel(String kind) {
  return switch (kind) {
    'income' => 'Receita',
    'expense' => 'Despesa',
    'cardInstallment' => 'Cartão',
    'invoicePayment' => 'Fatura',
    _ => 'Movimentação',
  };
}

String statusLabel(String status) => switch (status) {
      'paid' => 'Pago',
      'partial' => 'Parcial',
      _ => 'Pendente',
    };
