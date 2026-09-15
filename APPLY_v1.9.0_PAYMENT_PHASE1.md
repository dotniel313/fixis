# Aplicación — FIXIS PRO v1.9.0 Payment Flow Phase 1

## 1. Backend

Migration 018 ya debe estar aplicada y validada.

Ejecuta después:

```text
supabase/migrations/019_bank_transfer_ui_support_v1_9_0.sql
```

Luego ejecuta:

```text
docs/VALIDATE_019.sql
```

## 2. Configurar la cuenta bancaria

Abre:

```text
docs/CONFIGURE_BANK_ACCOUNT.sql
```

Reemplaza los placeholders con la cuenta empresarial que FIXIS utilizará para recibir transferencias y ejecuta el `INSERT`.

No hardcodees estos datos en Flutter.

## 3. Flutter

Copiar/reemplazar:

```text
lib/features/customer/providers/customer_repository.dart
lib/features/customer/screens/customer_job_detail_screen.dart
lib/features/customer/screens/customer_payment_screen.dart
```

Agregar dependencia:

```bash
flutter pub add image_picker
flutter clean
flutter pub get
flutter analyze
```

## 4. iOS

Si tu `Info.plist` todavía no lo tiene, agrega una descripción de acceso a Fotos:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>FIXIS necesita acceder a tus fotos para adjuntar el comprobante de transferencia.</string>
```

## 5. Regla crítica

El cliente puede subir el voucher, pero:

```text
voucher != payment confirmed
```

El trabajo permanece `work_completed` y el pago `pending_verification` hasta que un proceso trusted/service_role ejecute `verify_bank_transfer_trusted()`.
