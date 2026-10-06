
library;

class EspecialidadApi {
  final String idEspecialidad;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String medico;

  const EspecialidadApi({
    required this.idEspecialidad,
    required this.nombre,
    required this.precio,
    required this.medico,
    this.descripcion,
  });

  factory EspecialidadApi.fromJson(Map<String, dynamic> json) {
    return EspecialidadApi(
      idEspecialidad: json['idEspecialidad'].toString(),
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: (json['precio'] as num).toDouble(),
      medico: json['medico'] as String,
    );
  }
}

class HorarioApi {
  final String idHorario;
  final String idEspecialidad;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String consultorio;

  const HorarioApi({
    required this.idHorario,
    required this.idEspecialidad,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.consultorio,
  });

  String get horaFormateada {
    final partes = horaInicio.split(':');
    final h24 = int.tryParse(partes[0]) ?? 0;
    final m = partes.length > 1 ? partes[1] : '00';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ampm = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$m $ampm';
  }

  factory HorarioApi.fromJson(Map<String, dynamic> json) {
    final fechaRaw = json['fecha'] as String;
    final fechaSolo = fechaRaw.split('T').first;
    final partesFecha = fechaSolo.split('-').map(int.parse).toList();
    return HorarioApi(
      idHorario: json['idHorario'].toString(),
      idEspecialidad: json['idEspecialidad'].toString(),
      fecha: DateTime(partesFecha[0], partesFecha[1], partesFecha[2]),
      horaInicio: json['horaInicio'] as String,
      horaFin: json['horaFin'] as String,
      consultorio: json['consultorio'] as String,
    );
  }
}

class PagoResultado {
  final String idPago;
  final String estado;
  final double monto;
  final String comprobanteReferencia;

  const PagoResultado({
    required this.idPago,
    required this.estado,
    required this.monto,
    required this.comprobanteReferencia,
  });

  factory PagoResultado.fromJson(Map<String, dynamic> json) {
    final pago = json['pago'] as Map<String, dynamic>;
    final comprobante = json['comprobante'] as Map<String, dynamic>;
    return PagoResultado(
      idPago: pago['idPago'].toString(),
      estado: pago['estado'] as String,
      monto: (pago['monto'] as num).toDouble(),
      comprobanteReferencia: comprobante['referencia'] as String,
    );
  }
}
