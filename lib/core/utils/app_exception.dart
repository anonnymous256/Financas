class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is AppException) return error.message;
  return 'Não foi possível concluir a ação. Tente novamente.';
}
