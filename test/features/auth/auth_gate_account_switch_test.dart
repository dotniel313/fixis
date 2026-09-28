import 'package:fixis_pro/features/auth/providers/auth_repository.dart';
import 'package:fixis_pro/features/auth/screens/auth_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('un acceso admin anterior no aparece tras cambiar la sesion',
      (tester) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => AuthRepository(client)),
          appAccessProvider.overrideWith(
            (ref) async => const AppAccessDecision(
              AppAccessType.admin,
              userId: 'previous-admin',
            ),
          ),
        ],
        child: const MaterialApp(home: AuthGateScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pagos'), findsNothing);

    await client.dispose();
  });

  test('una decision de acceso solo pertenece a su usuario', () {
    const admin = AppAccessDecision(AppAccessType.admin, userId: 'admin-1');
    expect(admin.belongsTo('customer-2'), isFalse);
    expect(admin.belongsTo(null), isFalse);
    expect(admin.belongsTo('admin-1'), isTrue);
  });
}
