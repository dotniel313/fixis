# FIXIS PRO v1.10.7.3 — Customer Account Deletion Compliance

## Motivo

Antes de publicación en App Store / Google Play, el cliente debe contar con
una ruta clara para eliminar su cuenta.

## Incluye

En `Mi perfil` del cliente se agrega:

- sección visible `Eliminar cuenta`;
- botón `Eliminar mi cuenta`;
- confirmación explícita;
- advertencia de irreversibilidad;
- aclaración sobre datos que deban conservarse por obligaciones legales;
- ejecución del RPC `delete_user_account`;
- cierre de sesión automático;
- retorno al login después de eliminación exitosa.

## Backend

**NO requiere SQL** porque reutiliza el RPC existente:

`delete_user_account`

El mismo mecanismo ya usado por el perfil profesional.

## Importante para Google Play

Google Play también solicita un recurso web externo donde el usuario pueda
solicitar la eliminación de cuenta. Antes de publicación Android debemos
crear/publicar esa URL y declararla en Play Console.

## Aplicación

Reemplazar la `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba segura recomendada

No pruebes la eliminación con una cuenta que necesites conservar.

1. Crear/usar una cuenta cliente de prueba.
2. Entrar a Mi perfil.
3. Verificar que aparece `Eliminar mi cuenta`.
4. Pulsar y comprobar el diálogo.
5. Cancelar primero.
6. Con una cuenta desechable, confirmar eliminación.
7. Verificar retorno al login.
8. Intentar iniciar sesión nuevamente para comprobar el comportamiento esperado.
