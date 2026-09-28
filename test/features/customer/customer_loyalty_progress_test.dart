import 'package:flutter_test/flutter_test.dart';
import 'package:fixis_pro/features/customer/models/customer_loyalty_progress.dart';

void main() {
  test('el reconocimiento inicial termina exactamente al tercer pago', () {
    const before = CustomerLoyaltyProgress(2);
    const reached = CustomerLoyaltyProgress(3);

    expect(before.level, 'Primeros servicios');
    expect(before.nextGoal, 3);
    expect(before.remaining, 1);
    expect(before.progress, closeTo(2 / 3, 0.0001));

    expect(reached.level, 'Cliente recurrente');
    expect(reached.nextGoal, 10);
    expect(reached.remaining, 7);
    expect(reached.progress, 0.3);
  });

  test('el segundo reconocimiento se alcanza al décimo pago', () {
    const before = CustomerLoyaltyProgress(9);
    const reached = CustomerLoyaltyProgress(10);
    const later = CustomerLoyaltyProgress(11);

    expect(before.level, 'Cliente recurrente');
    expect(before.remaining, 1);
    expect(before.progress, 0.9);

    for (final progress in [reached, later]) {
      expect(progress.level, 'Cliente habitual');
      expect(progress.nextGoal, isNull);
      expect(progress.remaining, isNull);
      expect(progress.progress, isNull);
    }
  });

  test('una cuenta sin pagos muestra la primera meta', () {
    const progress = CustomerLoyaltyProgress(0);
    expect(progress.level, 'Primeros servicios');
    expect(progress.nextGoal, 3);
    expect(progress.remaining, 3);
    expect(progress.progress, 0);
  });
}
