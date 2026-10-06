import 'package:flutter/foundation.dart';
import '../data/models/paciente.dart';
import '../data/repositories/auth_local_repository.dart';

enum AuthStatus { idle, loading, error }

class AuthException implements Exception {
  final String message;
  final String code;
  AuthException(this.message, this.code);
}

class AuthProvider extends ChangeNotifier {
  final _authRepo = AuthLocalRepository();

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  int loginAttempts = 0;
  bool isBlocked = false;

  Paciente? currentPaciente;

  String? pendingDocumento;

  AuthException _mapError(Object e, String fallback) {
    if (e is LocalAuthException) {
      return AuthException(e.message, e.code);
    }
    return AuthException(fallback, 'ERROR_DESCONOCIDO');
  }

  Future<String> registrar({
    required String nombre,
    required String apellido,
    required String documento,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final codigo = await _authRepo.registrar(
        nombre: nombre,
        apellido: apellido,
        documento: documento,
        correo: correo,
        telefono: telefono,
        password: password,
      );
      pendingDocumento = documento;
      status = AuthStatus.idle;
      notifyListeners();
      return codigo;
    } catch (e) {
      final ex = _mapError(e, 'No se pudo crear la cuenta');
      status = AuthStatus.error;
      errorMessage = ex.message;
      notifyListeners();
      throw ex;
    }
  }

  Future<String> reenviarOtp(String documento) async {
    try {
      return await _authRepo.reenviarOtp(documento);
    } catch (e) {
      throw _mapError(e, 'No se pudo reenviar el código');
    }
  }

  Future<void> verificarCodigoSms(String documento, String codigo) async {
    try {
      currentPaciente = await _authRepo.verificarCodigoSms(documento, codigo);
      notifyListeners();
    } catch (e) {
      throw _mapError(e, 'No se pudo verificar el código');
    }
  }

  Future<void> validarCodigoRecuperacion(
      String documento, String codigo) async {
    try {
      await _authRepo.validarCodigoRecuperacion(documento, codigo);
    } catch (e) {
      throw _mapError(e, 'Código incorrecto');
    }
  }

  Future<bool> login(String dni, String password) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      currentPaciente = await _authRepo.login(dni, password);
      loginAttempts = 0;
      isBlocked = false;
      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } catch (e) {
      final ex = _mapError(e, 'DNI o contraseña incorrectos');
      status = AuthStatus.error;
      errorMessage = ex.message;

      if (ex.code == 'CUENTA_BLOQUEADA') {
        isBlocked = true;
      }
      if (e is LocalAuthException) {
        final intentos = e.extra['intentosFallidos'];
        if (intentos is int) loginAttempts = intentos;
      }
      notifyListeners();
      return false;
    }
  }

  void resetError() {
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<String> solicitarRecuperacion(String documento) async {
    try {
      pendingDocumento = documento;
      return await _authRepo.solicitarRecuperacion(documento);
    } catch (e) {
      throw _mapError(e, 'No se pudo solicitar la recuperación');
    }
  }

  Future<void> restablecerPassword(
      String documento, String codigo, String nuevaPassword) async {
    try {
      await _authRepo.restablecerPassword(documento, codigo, nuevaPassword);
      unblockAndResetPassword();
    } catch (e) {
      throw _mapError(e, 'No se pudo restablecer la contraseña');
    }
  }

  void unblockAndResetPassword() {
    isBlocked = false;
    loginAttempts = 0;
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepo.cerrarSesion();
    currentPaciente = null;
    notifyListeners();
  }

  Future<bool> intentarSesionAutomatica() async {
    try {
      final paciente = await _authRepo.obtenerPerfil();
      if (paciente == null) {
        await _authRepo.cerrarSesion();
        return false;
      }
      currentPaciente = paciente;
      notifyListeners();
      return true;
    } catch (_) {
      await _authRepo.cerrarSesion();
      return false;
    }
  }
}
