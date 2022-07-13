import 'dart:math';

extension Choice<T> on List<T> {
  T choice() {
    final random = Random();
    return this[random.nextInt(length)];
  }
}
