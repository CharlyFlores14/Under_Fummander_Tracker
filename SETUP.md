# Activar la sincronización entre teléfonos y navegadores

La app **funciona sin hacer nada de esto**: si no configurás Firebase, guarda todo en el
teléfono con `SharedPreferences` (y en el navegador en el `localStorage`, que es lo mismo
pero en la web), exactamente como antes. Esta guía es para el modo opcional en el que todo
el grupo comparte jugadores, mazos, partidas y temporadas.

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

Elegí el proyecto del paso 1 y marcá **android** y **web**.

> Marcar **web** no es opcional si querés usar la app en el navegador. En el repo,
> `DefaultFirebaseOptions.web` es un alias del placeholder de Android; recién cuando
> `flutterfire configure` reescribe el archivo con la app web registrada, el navegador
> tiene sus propias credenciales y puede conectarse a Firebase.

Esto genera dos archivos:

- `lib/firebase_options.dart` — **sobrescribe** el placeholder que está en el repo. Es
  esperado. Por eso nada escrito a mano vive en ese archivo. Acá quedan las credenciales
  de las dos plataformas.
- `android/app/google-services.json`. (La web no necesita ningún archivo aparte: todo lo
  suyo va en `firebase_options.dart`.)

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

Este interruptor vale para las dos plataformas: es el mismo proveedor para el teléfono y
para el navegador.

---

## Paso 4 — Registrar la huella SHA-1 (solo Android)

**Sin esto el login con Google falla siempre** en el teléfono, y el error que devuelve
Android no dice por qué. En el navegador no hace falta: ahí el login lo resuelve Firebase
Auth con una ventana emergente, sin firma de aplicación de por medio.

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

## Paso 5 — Completar `googleWebClientId` (solo Android)

> El nombre engaña: aunque el cliente OAuth sea "de tipo web", **este valor es para la app
> Android**. Es lo que `google_sign_in` necesita para que Google devuelva un `idToken`. La
> versión del navegador no lo usa para nada: Firebase Auth usa el cliente OAuth del
> proyecto por su cuenta. Si sólo te interesa la web, saltá este paso.

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
flutter run              # en el teléfono o el emulador
flutter run -d chrome    # en el navegador
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

## Paso 8 — Publicar la versión web (opcional)

Con `flutter run -d chrome` la app ya anda en tu computadora, pero sólo en tu computadora.
Para que el resto del grupo la abra desde cualquier lado hay que subirla a algún lado.
**Firebase Hosting** es gratis en el plan Spark (10 GB de archivos, 360 MB de tráfico por
día; una build de esta app pesa unos pocos MB) y es el mismo `firebase` que ya usaste en
el paso 6.

La primera vez, decile a qué proyecto apunta esta computadora:

```bash
firebase use --add
```

Elegí el proyecto del paso 1. Eso crea `.firebaserc`, que está en el `.gitignore` porque
es distinto para cada quien. Lo que sí vive en el repo es `firebase.json`, que ya tiene
configurado el hosting y las reglas de Firestore.

Después, cada vez que quieras publicar:

```bash
flutter build web --release
firebase deploy
```

`firebase deploy` sube **las dos cosas**: el sitio y las reglas de `firestore.rules`. Al
terminar imprime la URL, con la forma `https://<tu-proyecto>.web.app`.

> **Por qué justo esa URL.** `signInWithPopup` sólo funciona desde un dominio que esté en
> **Authentication → Settings → Authorized domains**, y Firebase agrega solo los dominios
> `*.web.app` y `*.firebaseapp.com` de tu propio proyecto. O sea que ahí el login anda sin
> tocar nada más. Si algún día le ponés un dominio propio, **hay que agregarlo a mano a esa
> lista** o el login va a fallar con `unauthorized-domain`.

Un detalle lindo y gratis: la página está declarada como PWA, así que desde el navegador
del teléfono se puede "Agregar a la pantalla de inicio" y queda como una app más, sin
pasar por ninguna tienda.

---

## Qué esperar cuando funciona

- Una partida cargada en un teléfono aparece en los otros en el momento, sin refrescar. Lo
  mismo entre el teléfono y una pestaña del navegador abierta al mismo tiempo: es el mismo
  grupo y los mismos datos.
- Sin señal en el local: se puede cargar igual. Firestore encola la escritura y la
  sincroniza sola cuando vuelve internet. En el navegador pasa igual, y la caché sobrevive
  aunque tengas varias pestañas abiertas.
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
| **En el navegador:** "have not been configured for web" al abrir | No marcaste **web** en `flutterfire configure` (paso 2) |
| **En el navegador:** "El navegador bloqueó la ventana de Google" | El bloqueador de ventanas emergentes; permitilas para este sitio |
| **En el navegador:** "Este dominio no está autorizado" | Estás en un dominio propio; agregalo en Authentication → Settings → Authorized domains (paso 8) |

Para ver el motivo real de un rechazo: en la consola, **Firestore → Reglas → Monitor de
reglas** muestra qué petición se denegó y por qué.

---

## Volver al modo local

En la pantalla de nube, **Salir del grupo**. La app vuelve a los datos guardados en ese
teléfono (o en ese navegador); el historial del grupo no se borra y se puede volver a
entrar con el mismo código.

Para desactivar la sincronización en Android, alcanza con vaciar `googleWebClientId` en
`lib/firebase_config.dart`. En el navegador ese valor no se usa, así que para apagarla ahí
hay que sacar Firebase del proyecto entero (volver `lib/firebase_options.dart` al
placeholder del repo).
