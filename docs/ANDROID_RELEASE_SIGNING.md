# Firma de Android para Fixis

El APK de `scripts/build_android_qa.sh` es solo para pruebas físicas. La
publicación en Google Play se prepara como Android App Bundle (`.aab`) firmado
con una clave de subida. El build `release` ya no acepta la clave `debug`.

## Primera clave de subida (FIXIS aun no registrada en Play Console)

Crear una sola clave de subida en el Mac y conservarla fuera del repositorio:

```bash
mkdir -p "$HOME/Documents/FIXIS-keys"
chmod 700 "$HOME/Documents/FIXIS-keys"
keytool -genkeypair -v \
  -keystore "$HOME/Documents/FIXIS-keys/upload-keystore.jks" \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keytool solicita contraseñas y datos de identidad de forma interactiva. Cuando
pregunte por la contraseña de la clave, se puede pulsar Enter para usar la del
almacen. No poner contraseñas en la linea de comandos ni compartirlas en chats.
Si `keytool` no aparece en PATH, consultar `flutter doctor -v` para ubicar
el JDK de Android Studio.

Configurar `android/key.properties` con la ruta absoluta del archivo
`upload-keystore.jks` y las contraseñas elegidas. Ese archivo esta ignorado
por Git. Protegerlo con `chmod 600 android/key.properties`. Crear una copia
privada y recuperable del keystore y de sus contraseñas antes de registrarlo
en Play Console.

## Configuración en el Mac que genera la publicación

Conservar la clave de subida fuera del repositorio. Si ya existe una clave
registrada en Play Console, reutilizarla; no generar otra por accidente.
Crear `android/key.properties` con estas cuatro propiedades y valores reales:

```properties
storeFile=/ruta/privada/upload-keystore.jks
storePassword=CONTRASEÑA_DEL_ALMACÉN
keyAlias=upload
keyPassword=CONTRASEÑA_DE_LA_CLAVE
```

`.env`, `android/key.properties` y los archivos `.jks` están excluidos de Git.
Guardar copia recuperable de la clave y sus contraseñas antes de publicar.

Desde la raíz del proyecto, con QA físico y financiero aprobado:

```bash
bash scripts/build_android_release.sh
```

El resultado queda en `build/app/outputs/bundle/release/app-release.aab`. El
script imprime su SHA-256 para identificar exactamente el archivo probado y
subido. Verificar en Play Console que la clave de subida coincida con la
registrada, además del código de versión y los requisitos de la ficha de la
app, antes de distribuirla.
