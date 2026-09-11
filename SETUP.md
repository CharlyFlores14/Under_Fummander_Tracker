# Activar la sincronización entre teléfonos

La app **funciona sin hacer nada de esto**: si no configurás Firebase, guarda todo en el
teléfono con `SharedPreferences`, exactamente como antes. Esta guía es para el modo
opcional en el que todo el grupo comparte jugadores, mazos, partidas y temporadas.

Son pasos de consola web y de terminal que requieren tu cuenta de Google; no se pueden
hacer desde el repositorio.

Tiempo estimado: 20-30 minutos, una sola vez.

---

## Por qué Firebase y por qué sale $0

| | Firebase Spark | Supabase Free |
|---|---|---|
| Costo | Gratis, sin tarjeta | Gratis |
| **Pausa por inactividad** | **Ninguna** | **Se pausa a la semana sin uso** |
| Offline | Incluido y activado por defecto | Hay que armarlo a mano |

Supabase queda descartado por la pausa: un grupo que se saltea tres semanas de partidas
vuelve y encuentra la app muerta.

Lo que consume este grupo contra los límites del plan Spark:

| Límite | Spark | Este grupo (500 partidas) |
|---|---|---|
| Datos guardados | 1 GiB | ~150 KB |
| Escrituras | 20.000/día | ~10/día |
| Lecturas | 50.000/día | unos cientos/día |

Tres órdenes de magnitud de margen. No hay forma de que esto pase a pago solo.

---

## Paso 0 — Cambiar el `applicationId` (hacelo antes que todo lo demás)

`android/app/build.gradle.kts` todavía dice:

```kotlin
applicationId = "com.example.under_fummander_tracker"
```

Google Play rechaza cualquier cosa que empiece con `com.example.`, y el id queda grabado
en el registro de la app Android dentro de Firebase. Cambiarlo después obliga a rehacer
los pasos 2 a 5.

Poné algo tuyo, por ejemplo `com.tuapellido.underfummander`, en las **dos** líneas del
archivo: `namespace` y `applicationId`.

---

## Paso 1 — Crear el proyecto de Firebase

1. Entrá a <https://console.firebase.google.com> y creá un proyecto.
2. Google Analytics es opcional; se puede desactivar.
3. En **Compilación → Firestore Database → Crear base de datos**, elegí la región más
   cercana y arrancá en **modo de producción** (las reglas buenas las publicamos en el
   paso 6).
4. Si en algún momento ofrece pasar al plan **Blaze**, decí que no. El plan **Spark**
   alcanza y sobra.

---

## Paso 2 — `flutterfire configure`

```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools    # si no lo tenés
firebase login
cd <la carpeta del proyecto>
flutterfire configure
```

Elegí el proyecto del paso 1 y marcá al menos **android**.

Esto genera dos archivos:

- `lib/firebase_options.dart` — **sobrescribe** el placeholder que está en el repo. Es
  esperado. Por eso nada escrito a mano vive en ese archivo.
- `android/app/google-services.json`.

Apenas aparece ese `google-services.json`, `android/app/build.gradle.kts` empieza a
aplicar el plugin de Google Services solo (está condicionado a que el archivo exista,
para que la app compile igual sin haber configurado nada).

> Ninguno de los dos tiene secretos (son claves públicas de cliente; lo que protege los
> datos son las reglas del paso 6), pero tampoco hace falta subirlos a un repo público.

Después:

```bash
flutter pub get
```

---

## Paso 3 — Activar el login con Google

En la consola: **Compilación → Authentication → Comenzar → Sign-in method → Google →
Habilitar**. Pedí un correo de asistencia y guardá.

---

## Paso 4 — Registrar la huella SHA-1

**Sin esto el login con Google falla siempre**, y el error que devuelve Android no dice
por qué.

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

En Windows, con Git Bash, la ruta es `~/.android/debug.keystore` igual; si `keytool` no
está en el PATH, vive dentro del JDK que trae Android Studio
(`.../jbr/bin/keytool.exe`).

Copiá la línea `SHA1:` y pegala en **Configuración del proyecto → Tus apps → la app
Android → Agregar huella digital**.

> ⚠️ `android/app/build.gradle.kts` firma la build de **release** con la clave de debug
> ("Signing with the debug keys for now"). Mientras siga así, esta única huella sirve
> para debug y para release. **El día que agregues un keystore de release de verdad hay
> que registrar también su SHA-1**, o el login va a andar en tu teléfono y fallar solo
> en la versión publicada.

Volvé a bajar el `google-services.json` actualizado después de agregar la huella
(**Tus apps → google-services.json**) y reemplazá el de `android/app/`.

---

## Paso 5 — Completar `googleWebClientId`

Abrí `android/app/google-services.json` y buscá dentro de `oauth_client` la entrada con
**`"client_type": 3`** (esa es la de tipo **web**):

```json
{
  "client_id": "1234567890-abcdefg....apps.googleusercontent.com",
  "client_type": 3
}
```

Copiá ese `client_id` a `lib/firebase_config.dart`:

```dart
const String googleWebClientId =
    '1234567890-abcdefg....apps.googleusercontent.com';
```

> **Este es el error más común de todos.** Si ponés el `client_id` con
> `"client_type": 1` (el de Android), `authenticate()` devuelve una cuenta pero **sin
> `idToken`**, y el login falla sin decir nada útil. Tiene que ser el de tipo 3.
>
> Si en `google-services.json` no aparece ningún cliente con `client_type: 3`, es porque
> todavía no registraste la huella SHA-1 (paso 4) o no volviste a bajar el archivo.

---

## Paso 6 — Publicar las reglas de seguridad

Las reglas están en `firestore.rules`, en la raíz del repo. Sin publicarlas, Firestore
rechaza todo y la app muestra "el servidor rechazó la operación".

**Opción A — desde la terminal:**

```bash
firebase deploy --only firestore:rules
```

(Si es la primera vez: `firebase init firestore` y apuntá a `firestore.rules`.)

**Opción B — desde la consola:** **Firestore Database → Reglas**, pegá el contenido del
archivo y **Publicar**.

Lo que hacen, en una línea: cada grupo solo lo leen y lo escriben sus miembros; el código
de invitación es el id del documento, así que sin el código no se llega a ningún lado; y
alguien de afuera con el código solo puede agregarse a sí mismo a la lista de miembros,
nada más.

---

## Paso 7 — Probar

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Dentro de la app, tocá el ícono de nube ☁️ arriba a la derecha:

1. **Iniciar sesión con Google.**
2. **Crear un grupo.** Si ya tenías partidas cargadas en el teléfono, el diálogo ofrece
   subirlas como contenido inicial del grupo.
3. Anotá el **código de 6 caracteres** y pasáselo al resto del grupo.
4. En el segundo teléfono: iniciar sesión → **Entrar con un código**.

Al entrar a un grupo que ya existe **nunca** se suben los datos locales: duplicaría a
todos los jugadores. Lo que tenías en ese teléfono queda intacto y vuelve si salís del
grupo.

---

## Qué esperar cuando funciona

- Una partida cargada en un teléfono aparece en los otros en el momento, sin refrescar.
- Sin señal en el local: se puede cargar igual. Firestore encola la escritura y la
  sincroniza sola cuando vuelve internet.
- Dos personas cargando partidas distintas la misma noche no se pisan: cada partida es un
  documento aparte.
- Si alguien edita **la misma** partida al mismo tiempo que otro, gana el último en
  guardar. Para un grupo de juego es razonable.

---

## Si algo falla

| Síntoma | Causa casi segura |
|---|---|
| La pantalla de nube dice "Sincronización sin configurar" | Falta el paso 2 o el paso 5 |
| El login con Google se cierra sin error | Falta la huella SHA-1 (paso 4) |
| "Google no devolvió un token de identidad" | `googleWebClientId` es el de Android y no el de tipo 3 (paso 5) |
| "El servidor rechazó la operación" | Faltan publicar las reglas (paso 6) |
| "No existe ningún grupo con ese código" | El código está mal escrito, o el grupo se borró |
| Anda en debug y falla en la APK de release | Falta el `INTERNET` en el manifest, o el SHA-1 del keystore de release |

Para ver el motivo real de un rechazo: en la consola, **Firestore → Reglas → Monitor de
reglas** muestra qué petición se denegó y por qué.

---

## Volver al modo local

En la pantalla de nube, **Salir del grupo**. La app vuelve a los datos guardados en ese
teléfono; el historial del grupo no se borra y se puede volver a entrar con el mismo
código.

Para desactivar la sincronización en todo el proyecto, alcanza con vaciar
`googleWebClientId` en `lib/firebase_config.dart`.
