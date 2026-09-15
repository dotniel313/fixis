import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// Pantalla conservada por compatibilidad de navegación.
/// El cierre económico real ocurre únicamente después de la confirmación del
/// cliente; `finish_job()` deja el servicio en `work_completed`.
class JobSuccessScreen extends StatelessWidget {
  final String jobId;

  const JobSuccessScreen({
    super.key,
    required this.jobId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200, width: 3),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Trabajo enviado a confirmación',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSlate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'La evidencia fue guardada. El cliente debe confirmar que el servicio fue completado.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.primaryBlue,
                      size: 30,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'El pago todavía no está disponible',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Al confirmar el cliente, FIXIS registra en el ledger el valor del profesional y la comisión de la plataforma usando el snapshot financiero del servicio.',
                      style: TextStyle(color: Colors.grey, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const DashboardScreen(),
                    ),
                    (_) => false,
                  );
                },
                child: const Text('Volver al Dashboard'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
