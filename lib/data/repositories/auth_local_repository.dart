import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../models/paciente.dart';

class LocalAuthException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic> extra;
  LocalAuthException(this.message, this.code, [this.extra = const {}]);

  @override
  String toString() => 'LocalAuthException($code): $message';
}

class AuthLocalRepository {
  static const _storage = FlutterSecureStorage();
  static const _kSesion = 'id_paciente_sesion';
  static const _otpMinutos = 10;
  static const _maxIntentos = 3;

  final _uuid = const Uuid();
  final _rand = Random.secure();

  // ───────────────────────── Sesión ─────────────────────────

  Future<String?> leerSesion() => _storage.read(key: _kSesion);

  Future<void> _guardarSesion(String idPaciente) =>
      _storage.write(key: _kSesion, value: idPaciente);

  Future<void> cerrarSesion() => _storage.delete(key: _kSesion);

  // ───────────────────────── Registro / OTP ─────────────────────────

  Future<String> registrar({
    required String nombre,
    required String apellido,
    required String documento,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    final db = await AppDatabase.instance.database;
    final correoNorm = correo.trim().toLowerCase();

    final dup = await db.query(
      'paciente',
      columns: ['documento', 'correo'],
      where: 'documento = ? OR correo = ?',
      whereArgs: [documento, correoNorm],
    );
    if (dup.isNotEmpty) {
      if (dup.first['documento'] == documento) {
        throw LocalAuthException(
            'Ya existe una cuenta con ese documento', 'DOCUMENTO_DUPLICADO');
      }
      throw LocalAuthException(
          'Ya existe una cuenta con ese correo', 'CORREO_DUPLICADO');
    }

    final id = _uuid.v4();
    await db.insert('paciente', {
      'id_paciente': id,
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'documento': documento,
      'correo': correoNorm,
      'telefono': telefono.trim(),
      'contrasena_hash': _hash(password),
      'created_at': DateTime.now().toIso8601String(),
    });
    return _generarOtp(db, id);
  }

  Future<String> reenviarOtp(String documento) async {
    final db = await AppDatabase.instance.database;
    final p = await _pacienteOError(db, documento);
    return _generarOtp(db, p['id_paciente'] as String);
  }

  Future<Paciente> verificarCodigoSms(String documento, String codigo) async {
    final db = await AppDatabase.instance.database;
    final p = await _pacienteOError(db, documento);
    final id = p['id_paciente'] as String;
    await _validarOtp(db, id, codigo);
    await _invalidarOtp(db, id);
    await _guardarSesion(id);
    return Paciente.fromMap(p);
  }

  // ───────────────────────── Login ─────────────────────────

  Future<Paciente> login(String documento, String password) async {
    final db = await AppDatabase.instance.database;
    final rows = await db
        .query('paciente', where: 'documento = ?', whereArgs: [documento]);
    if (rows.isEmpty) {
      throw LocalAuthException(
          'DNI o contraseña incorrectos', 'CREDENCIALES_INVALIDAS');
    }
    final p = rows.first;
    final id = p['id_paciente'] as String;

    if ((p['bloqueado'] as int) == 1) {
      throw LocalAuthException('Cuenta bloqueada', 'CUENTA_BLOQUEADA');
    }

    if (!_verificar(password, p['contrasena_hash'] as String)) {
      final intentos = (p['intentos_fallidos'] as int) + 1;
      final bloquear = intentos >= _maxIntentos;
      await db.update(
        'paciente',
        {
          'intentos_fallidos': intentos,
          'bloqueado': bloquear ? 1 : 0,
          if (bloquear) 'fecha_bloqueo': DateTime.now().toIso8601String(),
        },
        where: 'id_paciente = ?',
        whereArgs: [id],
      );
      if (bloquear) {
        throw LocalAuthException('Cuenta bloqueada', 'CUENTA_BLOQUEADA',
            {'intentosFallidos': intentos});
      }
      throw LocalAuthException('DNI o contraseña incorrectos',
          'CREDENCIALES_INVALIDAS', {'intentosFallidos': intentos});
    }

    await db.update('paciente', {'intentos_fallidos': 0},
        where: 'id_paciente = ?', whereArgs: [id]);
    await _guardarSesion(id);
    return Paciente.fromMap(p);
  }

  Future<Paciente?> obtenerPerfil() async {
    final id = await leerSesion();
    if (id == null) return null;
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('paciente', where: 'id_paciente = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Paciente.fromMap(rows.first);
  }

  // ───────────────────────── Recuperación ─────────────────────────

  Future<String> solicitarRecuperacion(String documento) async {
    final db = await AppDatabase.instance.database;
    final p = await _pacienteOError(db, documento);
    return _generarOtp(db, p['id_paciente'] as String);
  }

  Future<void> validarCodigoRecuperacion(
      String documento, String codigo) async {
    final db = await AppDatabase.instance.database;
    final p = await _pacienteOError(db, documento);
    await _validarOtp(db, p['id_paciente'] as String, codigo);
  }

  Future<void> restablecerPassword(
      String documento, String codigo, String nuevaPassword) async {
    final db = await AppDatabase.instance.database;
    final p = await _pacienteOError(db, documento);
    final id = p['id_paciente'] as String;
    await _validarOtp(db, id, codigo);
    await db.update(
      'paciente',
      {
        'contrasena_hash': _hash(nuevaPassword),
        'intentos_fallidos': 0,
        'bloqueado': 0,
        'fecha_bloqueo': null,
      },
      where: 'id_paciente = ?',
      whereArgs: [id],
    );
    await _invalidarOtp(db, id);
  }

  // ───────────────────────── Helpers ─────────────────────────

  Future<Map<String, Object?>> _pacienteOError(
      Database db, String documento) async {
    final rows = await db
        .query('paciente', where: 'documento = ?', whereArgs: [documento]);
    if (rows.isEmpty) {
      throw LocalAuthException(
          'No existe una cuenta con ese documento', 'PACIENTE_NO_ENCONTRADO');
    }
    return rows.first;
  }

  Future<String> _generarOtp(Database db, String idPaciente) async {
    final codigo = (100000 + _rand.nextInt(900000)).toString();
    await db.insert(
      'credencial',
      {
        'id_paciente': idPaciente,
        'codigo_hash': _hash(codigo),
        'fecha_expiracion': DateTime.now()
            .add(const Duration(minutes: _otpMinutos))
            .toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return codigo;
  }

  Future<void> _validarOtp(
      Database db, String idPaciente, String codigo) async {
    final rows = await db
        .query('credencial', where: 'id_paciente = ?', whereArgs: [idPaciente]);
    final hash = rows.isEmpty ? null : rows.first['codigo_hash'] as String?;
    final expira =
        rows.isEmpty ? null : rows.first['fecha_expiracion'] as String?;

    if (hash == null || expira == null) {
      throw LocalAuthException('Solicita un nuevo código', 'OTP_INEXISTENTE');
    }
    if (DateTime.parse(expira).isBefore(DateTime.now())) {
      throw LocalAuthException(
          'El código expiró, solicita uno nuevo', 'OTP_EXPIRADO');
    }
    if (!_verificar(codigo, hash)) {
      throw LocalAuthException('Código incorrecto', 'OTP_INVALIDO');
    }
  }

  Future<void> _invalidarOtp(Database db, String idPaciente) => db.update(
        'credencial',
        {'codigo_hash': null, 'fecha_expiracion': null},
        where: 'id_paciente = ?',
        whereArgs: [idPaciente],
      );

  // Hash con sal por valor: "sal$hash". Suficiente para un proyecto académico.
  String _hash(String valor) {
    final sal =
        base64Url.encode(List<int>.generate(16, (_) => _rand.nextInt(256)));
    return '$sal\$${_digest(sal, valor)}';
  }

  bool _verificar(String valor, String guardado) {
    final partes = guardado.split(r'$');
    if (partes.length != 2) return false;
    return _digest(partes[0], valor) == partes[1];
  }

  String _digest(String sal, String valor) =>
      sha256.convert(utf8.encode('$sal:$valor')).toString();
}
