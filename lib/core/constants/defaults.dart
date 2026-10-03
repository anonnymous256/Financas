class CategorySeed {
  const CategorySeed({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String kind;
  final String icon;
  final int color;
}

const defaultCategories = <CategorySeed>[
  CategorySeed(id: 'cat_salary', name: 'Salário', kind: 'income', icon: 'payments', color: 0xFF059669),
  CategorySeed(id: 'cat_freelance', name: 'Freelance', kind: 'income', icon: 'work', color: 0xFF4F46E5),
  CategorySeed(id: 'cat_investment', name: 'Investimentos', kind: 'income', icon: 'trending_up', color: 0xFF0F766E),
  CategorySeed(id: 'cat_sales', name: 'Vendas', kind: 'income', icon: 'storefront', color: 0xFFD97706),
  CategorySeed(id: 'cat_income_other', name: 'Outros', kind: 'income', icon: 'more_horiz', color: 0xFF64748B),
  CategorySeed(id: 'cat_food', name: 'Alimentação', kind: 'expense', icon: 'restaurant', color: 0xFFEA580C),
  CategorySeed(id: 'cat_home', name: 'Moradia', kind: 'expense', icon: 'home', color: 0xFF2563EB),
  CategorySeed(id: 'cat_transport', name: 'Transporte', kind: 'expense', icon: 'directions_car', color: 0xFF0891B2),
  CategorySeed(id: 'cat_health', name: 'Saúde', kind: 'expense', icon: 'medical', color: 0xFFE11D48),
  CategorySeed(id: 'cat_education', name: 'Educação', kind: 'expense', icon: 'school', color: 0xFF7C3AED),
  CategorySeed(id: 'cat_leisure', name: 'Lazer', kind: 'expense', icon: 'sports', color: 0xFFDB2777),
  CategorySeed(id: 'cat_shopping', name: 'Compras', kind: 'expense', icon: 'shopping_bag', color: 0xFFCA8A04),
  CategorySeed(id: 'cat_subs', name: 'Assinaturas', kind: 'expense', icon: 'subscriptions', color: 0xFF6D28D9),
  CategorySeed(id: 'cat_bills', name: 'Contas', kind: 'expense', icon: 'receipt', color: 0xFF92400E),
  CategorySeed(id: 'cat_tax', name: 'Impostos', kind: 'expense', icon: 'account_balance', color: 0xFF475569),
  CategorySeed(id: 'cat_expense_other', name: 'Outros', kind: 'expense', icon: 'more_horiz', color: 0xFF64748B),
];

const accountTypeLabels = <String, String>{
  'checking': 'Conta corrente',
  'savings': 'Conta poupança',
  'wallet': 'Carteira',
  'cash': 'Dinheiro',
  'digital': 'Conta digital',
  'investment': 'Investimentos',
  'other': 'Outras',
};

const paymentMethodLabels = <String, String>{
  'pix': 'Pix',
  'debit': 'Débito',
  'cash': 'Dinheiro',
  'boleto': 'Boleto',
  'transfer': 'Transferência',
  'card': 'Cartão de crédito',
  'other': 'Outro',
};

const frequencyLabels = <String, String>{
  'weekly': 'Semanal',
  'monthly': 'Mensal',
  'yearly': 'Anual',
};

const brandLabels = [
  'Visa',
  'Mastercard',
  'Elo',
  'American Express',
  'Hipercard',
  'Outra',
];

const colorPalette = <int>[
  0xFF0F766E,
  0xFF059669,
  0xFF2563EB,
  0xFF4F46E5,
  0xFF7C3AED,
  0xFFDB2777,
  0xFFE11D48,
  0xFFEA580C,
  0xFFD97706,
  0xFFCA8A04,
  0xFF0891B2,
  0xFF475569,
];

const iconKeys = <String>[
  'payments',
  'work',
  'trending_up',
  'storefront',
  'restaurant',
  'home',
  'directions_car',
  'medical',
  'school',
  'sports',
  'shopping_bag',
  'subscriptions',
  'receipt',
  'account_balance',
  'more_horiz',
  'savings',
  'wallet',
  'phone',
  'credit_card',
  'flag',
  'flight',
  'favorite',
  'beach',
  'devices',
  'bolt',
  'gas',
  'fitness',
  'pets',
];
