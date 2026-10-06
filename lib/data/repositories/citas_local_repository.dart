import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../models/cancelacion.dart';
import '../models/cita.dart';
import '../models/especialidad_horario.dart';
import 'auth_local_repository.dart';

class CitasException implements Exception {
  final String message;
  final String code;
  CitasException(this.message, this.code);

  @override
  String toString() => 'CitasException($code): $message';
}

class CitasLocalRepository {
  // Reglas asumidas (ajustar si el backend original define otras):
  // - Cancelar con 24 h o más de anticipación reintegra 100 %; con menos, 50 %.
  static const _horasReintegroTotal = 24;
  static const _estadosActivos = ['pendiente', 'confirmada', 'reprogramada'];

  final _uuid = const Uuid();
  final _auth = AuthLocalRepository();

  static const _selectCita = '''
    SELECT c.id_cita, c.estado, c.fecha_creacion,
           h.id_horario, h.fecha, h.hora_inicio, h.consultorio,
           e.id_especialidad, e.nombre, e.precio, e.medico
    FROM cita c
    JOIN horario h ON h.id_horario = c.id_horario
    JOIN especialidad e ON e.id_especialidad = h.id_especialidad
  ''';

  // ───────────────────────── Consultas ─────────────────────────

  /// Citas activas y futuras del paciente en sesión, ordenadas por fecha.
  Future<List<CitaDetalle>> listarMisCitas() async {
    final db = await AppDatabase.instance.database;
    final idPaciente = await _idPaciente();
    final rows = await db.rawQuery(
      '$_selectCita WHERE c.id_paciente = ? AND c.estado IN (?, ?, ?) '
      'ORDER BY h.fecha, h.hora_inicio',
      [idPaciente, ..._estadosActivos],
    );
    final ahora = DateTime.now();
    final citas = <CitaDetalle>[];
    for (final r in rows) {
      final c = await _mapDetalle(db, r);
      if (c.fechaHoraCita.isAfter(ahora)) citas.add(c);
    }
    return citas;
  }

  Future<List<EspecialidadApi>> listarEspecialidades() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('especialidad', orderBy: 'nombre');
    return rows
        .map((r) => EspecialidadApi(
              idEspecialidad: '${r['id_especialidad']}',
              nombre: r['nombre'] as String,
              descripcion: r['descripcion'] as String?,
              precio: (r['precio'] as num).toDouble(),
              medico: r['medico'] as String,
            ))
        .toList();
  }

  Future<List<HorarioApi>> listarHorarios({
    required String idEspecialidad,
    required DateTime fecha,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'horario',
      where: 'id_especialidad = ? AND fecha = ? AND disponible = 1',
      whereArgs: [int.tryParse(idEspecialidad) ?? -1, _fmtFecha(fecha)],
      orderBy: 'hora_inicio',
    );
    final ahora = DateTime.now();
    final esHoy = fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;

    return rows
        .where((r) {
          if (!esHoy) return true;
          final h = int.parse((r['hora_inicio'] as String).substring(0, 2));
          return h > ahora.hour;
        })
        .map((r) => HorarioApi(
              idHorario: '${r['id_horario']}',
              idEspecialidad: '${r['id_especialidad']}',
              fecha: DateTime(fecha.year, fecha.month, fecha.day),
              horaInicio: r['hora_inicio'] as String,
              horaFin: r['hora_fin'] as String,
              consultorio: r['consultorio'] as String,
            ))
        .toList();
  }

  // ───────────────────────── Crear cita ─────────────────────────

  Future<CitaDetalle> crearCita(String idHorario) async {
    final db = await AppDatabase.instance.database;
    final idPaciente = await _idPaciente();
    final id = _uuid.v4();

    await db.transaction((txn) async {
      final upd = await txn.update(
        'horario',
        {'disponible': 0},
        where: 'id_horario = ? AND disponible = 1',
        whereArgs: [int.tryParse(idHorario) ?? -1],
      );
      if (upd == 0) {
        throw CitasException(
            'El horario ya no está disponible', 'HORARIO_NO_DISPONIBLE');
      }
      await txn.insert('cita', {
        'id_cita': id,
        'id_paciente': idPaciente,
        'id_horario': int.parse(idHorario),
        'estado': 'pendiente',
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      await txn.insert('comprobante', {
        'id_cita': id,
        'tipo': 'reserva',
        'fecha_envio': DateTime.now().toIso8601String(),
        'referencia': _referencia(),
      });
    });

    return _detalle(db, id, idPaciente);
  }

  // ───────────────────────── Pago ─────────────────────────

  /// metodo: cualquier valor que contenga "tarjeta" se confirma al instante;
  /// cualquier otro (p. ej. "caja") queda pendiente de pago en caja.
  Future<PagoResultado> registrarPago({
    required String idCita,
    required String metodo,
    Map<String, String>? tarjeta,
  }) async {
    final db = await AppDatabase.instance.database;
    final idPaciente = await _idPaciente();
    final cita = await _citaDelPaciente(db, idCita, idPaciente);

    if (cita['estado'] == 'cancelada') {
      throw CitasException('La cita está cancelada', 'CITA_CANCELADA');
    }
    final previo = await db.query('pago',
        where: "id_cita = ? AND estado IN ('pendiente','confirmado')",
        whereArgs: [idCita],
        limit: 1);
    if (previo.isNotEmpty) {
      throw CitasException(
          'Esta cita ya tiene un pago registrado', 'PAGO_EXISTENTE');
    }

    final esTarjeta = metodo.toLowerCase().contains('tarjeta');
    if (esTarjeta && tarjeta == null) {
      throw CitasException(
          'Ingresa los datos de la tarjeta', 'TARJETA_REQUERIDA');
    }

    final monto = (cita['precio'] as num).toDouble();
    final idPago = _uuid.v4();
    final referencia = _referencia();
    final ahora = DateTime.now().toIso8601String();
    final estado = esTarjeta ? 'confirmado' : 'pendiente';

    await db.transaction((txn) async {
      await txn.insert('pago', {
        'id_pago': idPago,
        'id_cita': idCita,
        'monto': monto,
        'estado': estado,
        'fecha_pago': esTarjeta ? ahora : null,
      });

      if (esTarjeta) {
        final digitos =
            _campo(tarjeta!, ['numero', 'numeroTarjeta', 'numero_tarjeta'])
                .replaceAll(RegExp(r'\D'), '');
        final ultimos = digitos.length >= 4
            ? digitos.substring(digitos.length - 4)
            : digitos;
        await txn.insert('pago_tarjeta', {
          'id_pago': idPago,
          // Solo se guardan los últimos 4 dígitos.
          'numero_tarjeta': '**** **** **** $ultimos',
          'titular': _campo(tarjeta, ['titular', 'nombre']),
          'fecha_vencimiento': _campo(tarjeta,
              ['fechaVencimiento', 'vencimiento', 'fecha_vencimiento']),
        });
        await txn.update('cita', {'estado': 'confirmada'},
            where: 'id_cita = ?', whereArgs: [idCita]);
      } else {
        await txn.insert('pago_caja', {
          'id_pago': idPago,
          'codigo_comprobante': referencia,
        });
      }

      await txn.insert('comprobante', {
        'id_cita': idCita,
        'tipo': 'pago',
        'fecha_envio': ahora,
        'referencia': referencia,
      });
    });

    return PagoResultado(
      idPago: idPago,
      estado: estado,
      monto: monto,
      comprobanteReferencia: referencia,
    );
  }

  // ───────────────────────── Cancelar ─────────────────────────

  Future<CancelacionResultado> cancelarCita({
    required String idCita,
    Map<String, String>? cuentaBancaria,
  }) async {
    final db = await AppDatabase.instance.database;
    final idPaciente = await _idPaciente();
    final cita = await _citaDelPaciente(db, idCita, idPaciente);

    if (cita['estado'] == 'cancelada') {
      throw CitasException('La cita ya fue cancelada', 'CITA_YA_CANCELADA');
    }

    // Solo hay reintegro si el pago ya estaba confirmado.
    final pagos = await db.query('pago',
        where: 'id_cita = ? AND estado = ?',
        whereArgs: [idCita, 'confirmado'],
        limit: 1);

    ReintegroInfo? reintegro;
    String? idPagoReintegro;
    if (pagos.isNotEmpty) {
      final horas = _fechaHora(cita).difference(DateTime.now()).inHours;
      final porcentaje = horas >= _horasReintegroTotal ? 100 : 50;
      final pagado = (pagos.first['monto'] as num).toDouble();
      reintegro = ReintegroInfo(
        monto: double.parse((pagado * porcentaje / 100).toStringAsFixed(2)),
        porcentaje: porcentaje,
      );
      idPagoReintegro = pagos.first['id_pago'] as String;
      if (cuentaBancaria == null) {
        throw CitasException(
            'Ingresa una cuenta bancaria para recibir el reintegro',
            'CUENTA_REQUERIDA');
      }
    }

    final reint = reintegro;
    final pagoId = idPagoReintegro;
    final cuenta = cuentaBancaria;

    await db.transaction((txn) async {
      await txn.update('cita', {'estado': 'cancelada'},
          where: 'id_cita = ?', whereArgs: [idCita]);
      await txn.update('horario', {'disponible': 1},
          where: 'id_horario = ?', whereArgs: [cita['id_horario']]);
      await txn.update('pago', {'estado': 'rechazado'},
          where: "id_cita = ? AND estado = 'pendiente'", whereArgs: [idCita]);

      if (reint != null && pagoId != null && cuenta != null) {
        final idCuenta = _uuid.v4();
        await txn.insert('cuenta_bancaria', {
          'id_cuenta': idCuenta,
          'id_paciente': idPaciente,
          'numero_cuenta': _campo(
              cuenta, ['numeroCuenta', 'numero', 'numero_cuenta', 'cuenta']),
          'titular': _campo(cuenta, ['titular']),
          'banco': _campo(cuenta, ['banco']),
          'validada': 1,
        });
        await txn.insert('reembolso', {
          'id_reintegro': _uuid.v4(),
          'id_pago': pagoId,
          'id_cuenta': idCuenta,
          'monto': reint.monto,
          'porcentaje': reint.porcentaje,
          'estado': 'pendiente',
        });
      }
    });

    return CancelacionResultado(estado: 'cancelada', reintegro: reintegro);
  }

  // ───────────────────────── Reprogramar ─────────────────────────

  /// metodoPago y tarjeta se aceptan por compatibilidad, pero esta versión
  /// local no cobra recargo por reprogramar.
  Future<CitaDetalle> reprogramarCita({
    required String idCita,
    required String idNuevoHorario,
    String? metodoPago,
    Map<String, String>? tarjeta,
  }) async {
    final db = await AppDatabase.instance.database;
    final idPaciente = await _idPaciente();
    final cita = await _citaDelPaciente(db, idCita, idPaciente);

    if (cita['estado'] == 'cancelada') {
      throw CitasException('La cita está cancelada', 'CITA_CANCELADA');
    }

    final nuevo = int.tryParse(idNuevoHorario) ?? -1;

    await db.transaction((txn) async {
      final upd = await txn.update(
        'horario',
        {'disponible': 0},
        where: 'id_horario = ? AND disponible = 1',
        whereArgs: [nuevo],
      );
      if (upd == 0) {
        throw CitasException(
            'El horario ya no está disponible', 'HORARIO_NO_DISPONIBLE');
      }
      await txn.update('horario', {'disponible': 1},
          where: 'id_horario = ?', whereArgs: [cita['id_horario']]);
      await txn.update('cita', {'id_horario': nuevo, 'estado': 'reprogramada'},
          where: 'id_cita = ?', whereArgs: [idCita]);
      await txn.insert('comprobante', {
        'id_cita': idCita,
        'tipo': 'reprogramacion',
        'fecha_envio': DateTime.now().toIso8601String(),
        'referencia': _referencia(),
      });
    });

    return _detalle(db, idCita, idPaciente);
  }

  // ───────────────────────── Helpers ─────────────────────────

  Future<String> _idPaciente() async {
    final id = await _auth.leerSesion();
    if (id == null) {
      throw CitasException('Inicia sesión para continuar', 'SIN_SESION');
    }
    return id;
  }

  Future<Map<String, Object?>> _citaDelPaciente(
      Database db, String idCita, String idPaciente) async {
    final rows = await db.rawQuery(
      '$_selectCita WHERE c.id_cita = ? AND c.id_paciente = ?',
      [idCita, idPaciente],
    );
    if (rows.isEmpty) {
      throw CitasException('Cita no encontrada', 'CITA_NO_ENCONTRADA');
    }
    return rows.first;
  }

  Future<CitaDetalle> _detalle(
          Database db, String idCita, String idPaciente) async =>
      _mapDetalle(db, await _citaDelPaciente(db, idCita, idPaciente));

  Future<CitaDetalle> _mapDetalle(
      DatabaseExecutor db, Map<String, Object?> r) async {
    final pagos = await db.query(
      'pago',
      where: 'id_cita = ? AND estado != ?',
      whereArgs: [r['id_cita'], 'rechazado'],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    final f = (r['fecha'] as String).split('-').map(int.parse).toList();

    return CitaDetalle(
      idCita: r['id_cita'] as String,
      estado: r['estado'] as String,
      fechaCreacion:
          DateTime.tryParse(r['fecha_creacion'] as String) ?? DateTime.now(),
      horario: HorarioCita(
        idHorario: '${r['id_horario']}',
        fecha: DateTime(f[0], f[1], f[2]),
        horaInicio: r['hora_inicio'] as String,
        consultorio: r['consultorio'] as String,
      ),
      especialidad: EspecialidadCita(
        idEspecialidad: '${r['id_especialidad']}',
        nombre: r['nombre'] as String,
        precio: (r['precio'] as num).toDouble(),
        medico: r['medico'] as String,
      ),
      pago: pagos.isEmpty
          ? null
          : PagoCita(
              idPago: pagos.first['id_pago'] as String,
              estado: pagos.first['estado'] as String,
              monto: (pagos.first['monto'] as num).toDouble(),
            ),
    );
  }

  DateTime _fechaHora(Map<String, Object?> r) {
    final f = (r['fecha'] as String).split('-').map(int.parse).toList();
    final h = (r['hora_inicio'] as String).split(':').map(int.parse).toList();
    return DateTime(f[0], f[1], f[2], h[0], h.length > 1 ? h[1] : 0);
  }

  // Tolera distintos nombres de clave según cómo envíen los datos las pantallas.
  String _campo(Map<String, String> m, List<String> claves) {
    for (final k in claves) {
      final v = m[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _referencia() =>
      'CMP-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

  String _fmtFecha(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
}
