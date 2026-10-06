# MediCare+

Aplicación móvil para **iOS y Android** que permite a los pacientes gestionar sus citas médicas: reservar, consultar, reprogramar y cancelar, con registro de pago y comprobantes.

Está desarrollada con **Flutter** y funciona de forma **100 % local**: guarda todos los datos en una base **SQLite** dentro del dispositivo, así que no necesita servidor ni conexión a internet.

> Proyecto académico. Todos los datos de ejemplo (médicos, especialidades, precios) son ficticios.

---

## Funcionalidades

**Cuenta y acceso**

- Registro de pacientes con DNI, correo, teléfono y contraseña.
- Verificación por código OTP (simulado: el código se muestra en pantalla).
- Inicio de sesión con DNI y contraseña.
- Bloqueo de la cuenta tras 3 intentos fallidos.
- Recuperación de contraseña mediante código de verificación.
- Sesión persistente guardada de forma segura en el dispositivo.

**Citas**

- **Nueva cita:** elige especialidad, fecha y turno disponible.
- **Mis citas:** listado de citas con su estado (pendiente, confirmada, reprogramada o cancelada).
- **Reprogramar:** cambia una cita activa a otro día y horario disponible.
- **Cancelar:** cancela una cita con reembolso (100 % o 50 %) hacia una cuenta bancaria registrada.

**Pagos y comprobantes**

- Pago con tarjeta (se confirma al instante) o pago en caja el día de la cita.
- La tarjeta se guarda enmascarada (solo los últimos 4 dígitos) y el CVV nunca se almacena.
- Comprobantes de reserva, reprogramación y pago.

---

## Tecnologías

| Área                  | Tecnología                                         |
| --------------------- | -------------------------------------------------- |
| Framework             | Flutter (Dart `>=3.3.0 <4.0.0`)                    |
| Base de datos local   | `sqflite` (SQLite)                                 |
| Navegación            | `go_router`                                        |
| Estado                | `provider`                                         |
| Almacenamiento seguro | `flutter_secure_storage`                           |
| Seguridad             | `crypto` (hash con sal para contraseñas y códigos) |
| Identificadores       | `uuid`                                             |
| Interfaz              | Material Design, `google_fonts`, `intl`            |

---

## Estructura del proyecto

```
lib/
├── main.dart
├── core/
│   ├── db/            # Base de datos SQLite, esquema y datos semilla
│   ├── routes/        # Rutas de la app
│   ├── theme/         # Colores y tema
│   └── utils/         # Formateadores de entrada (tarjeta, vencimiento)
├── data/
│   ├── models/        # Paciente, Cita, Especialidad/Horario, Cancelación
│   └── repositories/  # Lógica de acceso a datos (auth y citas)
├── providers/         # Estado de autenticación y citas
├── screens/
│   ├── auth/          # Splash, login, registro, recuperar contraseña
│   ├── citas/         # Nueva, mis citas, reprogramar, cancelar
│   └── dashboard/     # Pantalla de inicio
└── widgets/           # Componentes reutilizables
```

---

## Base de datos

La base `medicare.db` se crea automáticamente la primera vez que se abre la app.

- **Tablas:** `especialidad`, `horario`, `paciente`, `credencial`, `cuenta_bancaria`, `cita`, `comprobante`, `pago`, `pago_tarjeta`, `pago_caja` y `reembolso`.
- **Datos semilla:** 5 especialidades (Cardiología, Dermatología, Nutrición, Psicología y Medicina General), cada una con su médico y precio.
- **Horarios:** en cada arranque la app genera turnos para los próximos 30 días, de lunes a sábado, en los bloques 09:00, 10:00, 11:00, 15:00 y 16:00.

---

## Cómo ejecutarlo

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.3 o superior
- Android Studio (para Android) o Xcode en macOS (para iOS)
- Un emulador, simulador o dispositivo físico

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/Xiongsho6/App_IOS.git
cd App_IOS

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar la app
flutter run
```

Para elegir un dispositivo concreto:

```bash
flutter devices
flutter run -d <id_del_dispositivo>
```

### Compilar

```bash
flutter build apk      # Android
flutter build ios      # iOS (requiere macOS y Xcode)
```

### Análisis del código

```bash
flutter analyze
```

---

## Cómo probarlo

1. Abre la app y crea una cuenta desde **Registro**.
2. Ingresa el código de verificación que aparece en pantalla.
3. Desde el inicio, reserva una **nueva cita** y elige un método de pago.
4. Revisa la cita en **Mis citas**, y prueba **reprogramarla** o **cancelarla**.

---

## Autor

**Jaren Fabrizio Fernández Sánchez**
Estudiante de la Universidad Norbert Wiener.
