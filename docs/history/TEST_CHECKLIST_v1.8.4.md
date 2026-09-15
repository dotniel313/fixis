# Test Checklist — v1.8.4 FIXIS Live

1. `flutter analyze` → 0 errors / 0 warnings.
2. Llevar un job real hasta `authorized`.
3. FIXI: tocar **Ir al cliente** y aceptar ubicación.
4. Verificar en Supabase: job `en_route` y fila en `professional_live_locations` con `sharing_active=true`.
5. Mantener detalle FIXI abierto y desplazarse >15 m o esperar nuevas posiciones; confirmar cambio de `updated_at`.
6. Cliente: abrir detalle del mismo job y verificar estado **FIXI en camino** + tarjeta FIXIS Live.
7. Confirmar que la hora/coordenadas cambien por Realtime.
8. FIXI: tocar **Llegué**.
9. Verificar job `arrived` y `sharing_active=false`.
10. Cliente: verificar **Tu FIXI llegó** y última ubicación.
11. FIXI: tocar **Iniciar servicio**.
12. Verificar job `in_progress`.
13. Confirmar que no se siguen publicando posiciones después de `arrived/in_progress`.
