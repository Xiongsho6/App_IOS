import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  static const int _version = 3;
  static const int _diasAdelante = 30;
  static const List<String> _horas = [
    '09:00',
    '10:00',
    '11:00',
    '15:00',
    '16:00'
  ];

  // Datos semilla (ficticios). precio y medico los exige EspecialidadCita.
  static const List<Map<String, Object>> _especialidades = [
    {
      'nombre': 'Cardiología',
      'descripcion': 'Salud del corazón',
      'precio': 120.0,
      'medico': 'Dr. Andrés Quispe'
    },
    {
      'nombre': 'Dermatología',
      'descripcion': 'Cuidado de la piel',
      'precio': 100.0,
      'medico': 'Dra. Lucía Paredes'
    },
    {
      'nombre': 'Nutrición',
      'descripcion': 'Alimentación y control de peso',
      'precio': 80.0,
      'medico': 'Dra. Camila Rojas'
    },
    {
      'nombre': 'Psicología',
      'descripcion': 'Salud mental',
      'precio': 90.0,
      'medico': 'Dr. Marco Salazar'
    },
    {
      'nombre': 'Medicina General',
      'descripcion': 'Consulta general',
      'precio': 60.0,
      'medico': 'Dra. Elena Vargas'
    },
  ];

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medicare.db');
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _asegurarHorarios(db);
    return db;
  }

  // La base anterior era solo caché del servidor, así que se recrea completa.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('PRAGMA foreign_keys = OFF');
      for (final t in [
        'reembolso',
        'pago_caja',
        'pago_tarjeta',
        'pago',
        'comprobante',
        'cita',
        'cuenta_bancaria',
        'credencial',
        'paciente',
        'horario',
        'especialidad',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $t');
      }
      await db.execute('PRAGMA foreign_keys = ON');
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE especialidad (
        id_especialidad INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre          TEXT UNIQUE NOT NULL,
        descripcion     TEXT,
        precio          REAL NOT NULL DEFAULT 0,
        medico          TEXT NOT NULL DEFAULT ''
      )
    ''');

    batch.execute('''
      CREATE TABLE horario (
        id_horario      INTEGER PRIMARY KEY AUTOINCREMENT,
        id_especialidad INTEGER NOT NULL REFERENCES especialidad(id_especialidad),
        fecha           TEXT NOT NULL,
        hora_inicio     TEXT NOT NULL,
        hora_fin        TEXT NOT NULL,
        consultorio     TEXT NOT NULL,
        disponible      INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_horario_especialidad ON horario(id_especialidad, fecha, disponible)');

    batch.execute('''
      CREATE TABLE paciente (
        id_paciente       TEXT PRIMARY KEY,
        nombre            TEXT NOT NULL,
        apellido          TEXT NOT NULL,
        documento         TEXT UNIQUE NOT NULL,
        correo            TEXT UNIQUE NOT NULL,
        telefono          TEXT NOT NULL,
        contrasena_hash   TEXT NOT NULL,
        intentos_fallidos INTEGER NOT NULL DEFAULT 0,
        bloqueado         INTEGER NOT NULL DEFAULT 0,
        fecha_bloqueo     TEXT,
        created_at        TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_paciente_documento ON paciente(documento)');

    // OTP simulado (se muestra en pantalla, igual que otpDev en el backend)
    batch.execute('''
      CREATE TABLE credencial (
        id_paciente      TEXT PRIMARY KEY REFERENCES paciente(id_paciente) ON DELETE CASCADE,
        codigo_hash      TEXT,
        fecha_expiracion TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE cuenta_bancaria (
        id_cuenta     TEXT PRIMARY KEY,
        id_paciente   TEXT NOT NULL REFERENCES paciente(id_paciente) ON DELETE CASCADE,
        numero_cuenta TEXT NOT NULL,
        titular       TEXT NOT NULL,
        banco         TEXT NOT NULL,
        validada      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_cuenta_paciente ON cuenta_bancaria(id_paciente)');

    batch.execute('''
      CREATE TABLE cita (
        id_cita        TEXT PRIMARY KEY,
        id_paciente    TEXT NOT NULL REFERENCES paciente(id_paciente),
        id_horario     INTEGER NOT NULL REFERENCES horario(id_horario),
        estado         TEXT NOT NULL DEFAULT 'pendiente'
                       CHECK (estado IN ('pendiente','confirmada','cancelada','reprogramada')),
        fecha_creacion TEXT NOT NULL
      )
    ''');
    batch
        .execute('CREATE INDEX idx_cita_paciente ON cita(id_paciente, estado)');
    batch.execute('CREATE INDEX idx_cita_horario ON cita(id_horario)');

    batch.execute('''
      CREATE TABLE comprobante (
        id_comprobante INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cita        TEXT NOT NULL REFERENCES cita(id_cita) ON DELETE CASCADE,
        tipo           TEXT NOT NULL CHECK (tipo IN ('reserva','reprogramacion','pago')),
        fecha_envio    TEXT NOT NULL,
        referencia     TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_comprobante_cita ON comprobante(id_cita)');

    batch.execute('''
      CREATE TABLE pago (
        id_pago     TEXT PRIMARY KEY,
        id_cita     TEXT NOT NULL REFERENCES cita(id_cita) ON DELETE CASCADE,
        monto       REAL NOT NULL,
        estado      TEXT NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente','confirmado','rechazado')),
        fecha_pago  TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_pago_cita ON pago(id_cita)');

    batch.execute('''
      CREATE TABLE pago_tarjeta (
        id_pago             TEXT PRIMARY KEY REFERENCES pago(id_pago) ON DELETE CASCADE,
        numero_tarjeta      TEXT NOT NULL,
        titular             TEXT NOT NULL,
        fecha_vencimiento   TEXT NOT NULL,
        intentos_rechazados INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE pago_caja (
        id_pago            TEXT PRIMARY KEY REFERENCES pago(id_pago) ON DELETE CASCADE,
        codigo_comprobante TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE reembolso (
        id_reintegro TEXT PRIMARY KEY,
        id_pago      TEXT NOT NULL REFERENCES pago(id_pago),
        id_cuenta    TEXT NOT NULL REFERENCES cuenta_bancaria(id_cuenta),
        monto        REAL NOT NULL,
        porcentaje   INTEGER NOT NULL CHECK (porcentaje IN (100, 50)),
        estado       TEXT NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente','confirmado','rechazado'))
      )
    ''');
    batch.execute('CREATE INDEX idx_reembolso_pago ON reembolso(id_pago)');

    for (final e in _especialidades) {
      batch.insert('especialidad', e);
    }

    await batch.commit(noResult: true);
  }

  // Mantiene siempre horarios disponibles para los próximos días (sin domingos).
  // Se ejecuta en cada arranque; solo inserta lo que falta.
  Future<void> _asegurarHorarios(Database db) async {
    final especialidades =
        await db.query('especialidad', columns: ['id_especialidad']);
    if (especialidades.isEmpty) return;

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final existentes = await db.query(
      'horario',
      columns: ['id_especialidad', 'fecha', 'hora_inicio'],
      where: 'fecha >= ?',
      whereArgs: [_fmtFecha(hoy)],
    );
    final claves = existentes
        .map((r) => '${r['id_especialidad']}|${r['fecha']}|${r['hora_inicio']}')
        .toSet();

    final batch = db.batch();
    for (final esp in especialidades) {
      final id = esp['id_especialidad'] as int;
      for (var d = 0; d < _diasAdelante; d++) {
        final dia = DateTime(hoy.year, hoy.month, hoy.day + d);
        if (dia.weekday == DateTime.sunday) continue;
        final fecha = _fmtFecha(dia);
        for (final h in _horas) {
          final hora = int.parse(h.substring(0, 2));
          if (d == 0 && hora <= ahora.hour) continue;
          if (claves.contains('$id|$fecha|$h')) continue;
          batch.insert('horario', {
            'id_especialidad': id,
            'fecha': fecha,
            'hora_inicio': h,
            'hora_fin': '${(hora + 1).toString().padLeft(2, '0')}:00',
            'consultorio': 'Consultorio ${100 + id}',
            'disponible': 1,
          });
        }
      }
    }
    await batch.commit(noResult: true);
  }

  String _fmtFecha(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medicare.db');
    await deleteDatabase(path);
    _db = null;
  }
}
