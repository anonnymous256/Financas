String? validateRequired(String? value, String label) {
  if (value == null || value.trim().isEmpty) return '$label é obrigatório.';
  return null;
}

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Informe o nome completo.';
  if (value.trim().length < 3) return 'O nome precisa ter ao menos 3 caracteres.';
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Informe o e-mail.';
  final email = value.trim();
  final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  if (!ok) return 'Informe um e-mail válido.';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Informe a senha.';
  if (value.length < 6) return 'A senha precisa ter ao menos 6 caracteres.';
  return null;
}

String? validatePasswordConfirmation(String? value, String original) {
  final error = validatePassword(value);
  if (error != null) return error;
  if (value != original) return 'As senhas não conferem.';
  return null;
}

String? validatePositiveMoney(String? value, {bool allowZero = false}) {
  if (value == null || value.trim().isEmpty) return 'Informe um valor.';
  final text = value.trim().replaceAll('R\$', '').replaceAll(' ', '');
  var normalized = text;
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(normalized)) {
    normalized = normalized.replaceAll('.', '');
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null) return 'Valor inválido.';
  if (parsed < 0) return 'O valor não pode ser negativo.';
  if (!allowZero && parsed == 0) return 'O valor deve ser maior que zero.';
  return null;
}
