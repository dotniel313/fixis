# FIXIS PRO v1.10.8.3 — Photo QA Hotfix

## Hallazgos físicos
- Android Cliente: fotos iniciales llegan al Fixi, pero las miniaturas no podían abrirse.
- iPhone Fixi: captura ANTES lenta; al tomar DESPUÉS se reportó crash.

## Cambios
- Las fotos iniciales del cliente ahora se pueden abrir a pantalla completa.
- Visor con zoom/pan mediante InteractiveViewer.
- Miniaturas decodificadas con cache reducido para evitar memoria innecesaria.
- Captura de evidencia Fixi reducida a 1280x1280, calidad 55.
- `requestFullMetadata: false` para reducir trabajo extra del picker en iOS.
- Preview local reducida de 700 px a 420 px.
- Evicción explícita del preview anterior al repetir una foto.
- Sin cambios SQL, Supabase, finanzas, snapshots ni estados.

## QA requerido
1. Fixi abre 1–3 fotos iniciales y puede hacer zoom.
2. iPhone: tomar ANTES, repetir ANTES, tomar DESPUÉS.
3. Repetir el ciclo 3 veces.
4. Completar trabajo y confirmar subida de ambas evidencias.
5. Si iOS vuelve a cerrarse, capturar crash log de Xcode/Console para determinar causa nativa exacta.
