/// 带用户可读文案的业务异常：仓储层校验失败时抛出，UI 层直接 toast 其 message。
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
