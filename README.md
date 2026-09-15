# FIXIS Android QA Prep

Este paquete NO modifica la app.

El ZIP premium actual contiene `lib/`, pero no la configuración nativa `android/`.
Por eso este preflight debe ejecutarse en el proyecto Flutter real.

## Uso

Copia `fixis_android_preflight.sh` a la raíz de tu proyecto:

```bash
chmod +x fixis_android_preflight.sh
./fixis_android_preflight.sh
```

Generará:

```text
fixis_android_preflight_report.txt
```

Comparte ese archivo en el chat. Con él revisamos:
- AndroidManifest;
- permisos;
- SDK;
- applicationId;
- plugins;
- dispositivos;
- `flutter analyze`;
- build APK debug.

El script NO modifica archivos y NO toca signing.
