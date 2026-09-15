# Test Checklist — v1.8.1

1. `flutter analyze` sin errores.
2. Entrar como FIXI y activar En línea.
3. Aceptar permiso GPS.
4. Confirmar que el radar se active y permita elegir radio.
5. Entrar como cliente y crear trabajo confirmando GPS.
6. Verificar en Supabase que el job tenga latitude y longitude.
7. Volver como FIXI de categoría compatible y actualizar radar.
8. Confirmar que aparece la oportunidad con distancia en km.
9. Cambiar a un radio menor y verificar filtrado cuando aplique.
10. Aceptar la oportunidad y confirmar `status=accepted` y `assigned_pro_id` correcto.
11. Crear una solicitud de categoría incompatible y confirmar que no aparece.
12. Confirmar que trabajos sin coordenadas no aparecen en el radar.
