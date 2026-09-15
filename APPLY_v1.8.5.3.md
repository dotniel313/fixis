# Aplicación del hotfix v1.8.5.3

Reemplazar únicamente estos archivos en el proyecto actual:

- `lib/features/auth/providers/auth_repository.dart`
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/customer_signup_screen.dart`
- `lib/features/auth/screens/otp_screen.dart`
- `lib/features/jobs/providers/jobs_repository.dart`

No ejecutar SQL.

El template neutral de correo está en `docs/OTP_TEMPLATE_NEUTRAL_v1.8.5.3.html`.

Después:
```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```
