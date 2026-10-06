import 'package:flutter/foundation.dart';
import '../data/models/cita.dart';
import '../data/repositories/citas_local_repository.dart';

enum CitasStatus { idle, loading, error }

class CitasProvider extends ChangeNotifier {
  final _repo = CitasLocalRepository();

  CitasStatus status = CitasStatus.idle;
  String? errorMessage;
  List<CitaDetalle> citas = [];

  bool get isLoading => status == CitasStatus.loading;

  CitaDetalle? get proximaCita {
    if (citas.isEmpty) return null;
    final ordenadas = [...citas]
      ..sort((a, b) => a.fechaHoraCita.compareTo(b.fechaHoraCita));
    return ordenadas.first;
  }

  bool get tienePagoPendiente =>
      citas.any((c) => c.pago != null && c.pago!.pendienteEnCaja);

  Future<void> cargar() async {
    status = CitasStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      citas = await _repo.listarMisCitas();
      status = CitasStatus.idle;
    } catch (e) {
      status = CitasStatus.error;
      errorMessage = _mensajeError(e);
    }
    notifyListeners();
  }

  String _mensajeError(Object e) {
    if (e is CitasException) return e.message;
    return 'No se pudieron cargar tus citas';
  }
}
