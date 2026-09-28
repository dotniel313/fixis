import 'package:fixis_pro/features/auth/providers/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la decision de admin no pertenece a una sesion cliente', () {
    const admin = AppAccessDecision(AppAccessType.admin, userId: 'admin-1');

    expect(admin.belongsTo('customer-2'), isFalse);
    expect(admin.belongsTo(null), isFalse);
    expect(admin.belongsTo('admin-1'), isTrue);
  });

  test('una decision sin sesion no pertenece a una cuenta autenticada', () {
    const loggedOut = AppAccessDecision(AppAccessType.unauthenticated);

    expect(loggedOut.belongsTo(null), isTrue);
    expect(loggedOut.belongsTo('customer-2'), isFalse);
  });
}
