# FIXIS — Prueba Android física

## 1. Preparación
- Activar Opciones de desarrollador.
- Activar Depuración USB.
- Conectar por cable para la primera prueba.
- Autorizar la huella RSA en el teléfono.
- Confirmar con `flutter devices`.

## 2. Instalación limpia
```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 3. Auth
- Cliente OTP.
- Profesional OTP.
- Admin.
- Reenvío/cooldown.
- Cerrar sesión y volver a entrar.

## 4. Cliente
- Home premium.
- Avatar → Perfil.
- Cámara.
- Galería.
- Editar perfil.
- Crear servicio.
- GPS.
- Historial.
- Eliminar cuenta: probar diálogo; eliminación definitiva solo con cuenta desechable.

## 5. FIXI
- Dashboard.
- Radar OFF/ON.
- Ubicación.
- Radio 5/8/15/25.
- Oportunidades.
- Aceptar.
- Cotizar.
- En camino.
- Ruta + ETA.
- Llegó.
- En curso.
- Finalizar.
- Perfil/avatar.
- Nivel FIXIS.
- Wallet.
- Notificaciones.

## 6. Cliente + FIXI E2E
- Crear job.
- Aceptar.
- Cotizar.
- Aceptar cotización.
- Tracking.
- Completar.
- Aprobar.
- Pago.
- Historial.

## 7. Admin
- Conciliación.
- Evidencia.
- Historial.
- Liquidaciones.
- Ingresos FIXIS.
- Mi cuenta Admin.

## 8. Android UX específica
- Botón físico/gesto Atrás.
- Teclado abierto/cerrado.
- Permisos denegados y luego concedidos.
- App a background → volver.
- Pantalla bloqueada → volver.
- Rotación si está permitida.
- Cámara → cancelar.
- Galería → cancelar.
- GPS apagado.
- Red móvil/Wi‑Fi.
- Sin conexión y recuperación.

## 9. Criterio para RC1
- `flutter analyze`: 0 errores.
- APK debug instala y abre.
- E2E completo exitoso.
- Sin crashes.
- Sin bugs P0/P1.
- Permisos Android correctos.
- Signing release preparado.
- Google Play: URL externa de eliminación de cuenta publicada.
