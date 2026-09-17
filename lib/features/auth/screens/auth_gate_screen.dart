// FIXIS PRO v1.6.1 - Auth Gate multiperfil
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../admin/screens/admin_payments_screen.dart';
import '../../customer/screens/customer_home_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../providers/auth_repository.dart';
import 'access_restricted_screen.dart';
import 'login_screen.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(appAccessProvider);

    return accessAsync.when(
      loading: () => const _AccessLoadingScreen(),
      error: (error, _) => AccessRestrictedScreen(
        status: ProfessionalAccessStatus.unknown,
        onRetry: () async {
          ref.read(authRepositoryProvider).clearAccessCache();
          ref.invalidate(appAccessProvider);
        },
      ),
      data: (decision) {
        switch (decision.type) {
          case AppAccessType.unauthenticated:
            return const LoginScreen();
          case AppAccessType.professional:
            return const DashboardScreen();
          case AppAccessType.customer:
            return const CustomerHomeScreen();
          case AppAccessType.admin:
            return const AdminPaymentsScreen();
          case AppAccessType.restricted:
            return AccessRestrictedScreen(
              status: ProfessionalAccessStatus.unknown,
              profile: decision.profile,
              onRetry: () async {
                ref.read(authRepositoryProvider).clearAccessCache();
                ref.invalidate(appAccessProvider);
              },
            );
        }
      },
    );
  }
}

class _AccessLoadingScreen extends StatelessWidget {
  const _AccessLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryOrange,
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
