import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EspecialidadCita {
  final String idEspecialidad;
  final String nombre;
  final double precio;
  final String medico;

  const EspecialidadCita({
    required this.idEspecialidad,
    required this.nombre,
    required this.precio,
    required this.medico,
  });

  factory EspecialidadCita.fromJson(Map<String, dynamic> json) {
    return EspecialidadCita(
      idEspecialidad: json['idEspecialidad'].toString(),
      nombre: json['nombre'] as String,
      precio: (json['precio'] as num).toDouble(),
      medico: json['medico'] as String,
    );
  }
}

class HorarioCita {
  final String idHorario;
  final DateTime fecha;
  final String horaInicio;
  final String consultorio;

  const HorarioCita({
    required this.idHorario,
    required this.fecha,
    required this.horaInicio,
    required this.consultorio,
  });

  DateTime get fechaHora {
    final partes = horaInicio.split(':');
    final h = int.tryParse(partes[0]) ?? 0;
    final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  factory HorarioCita.fromJson(Map<String, dynamic> json) {

    final fechaRaw = json['fecha'] as String;
    final fechaSolo = fechaRaw.split('T').first;
    final partesFecha = fechaSolo.split('-').map(int.parse).toList();
    return HorarioCita(
      idHorario: json['idHorario'].toString(),
      fecha: DateTime(partesFecha[0], partesFecha[1], partesFecha[2]),
      horaInicio: json['horaInicio'] as String,
      consultorio: json['consultorio'] as String,
    );
  }
}

class PagoCita {
  final String idPago;
  final String estado;
  final double monto;

  const PagoCita({
    required this.idPago,
    required this.estado,
    required this.monto,
  });

  bool get confirmado => estado == 'confirmado';
  bool get pendienteEnCaja => estado == 'pendiente';

  factory PagoCita.fromJson(Map<String, dynamic> json) {
    return PagoCita(
      idPago: json['idPago'].toString(),
      estado: json['estado'] as String,
      monto: (json['monto'] as num).toDouble(),
    );
  }
}

class CitaDetalle {
  final String idCita;
  final String estado;
  final DateTime fechaCreacion;
  final HorarioCita horario;
  final EspecialidadCita especialidad;
  final PagoCita? pago;

  const CitaDetalle({
    required this.idCita,
    required this.estado,
    required this.fechaCreacion,
    required this.horario,
    required this.especialidad,
    this.pago,
  });

  DateTime get fechaHoraCita => horario.fechaHora;

  factory CitaDetalle.fromJson(Map<String, dynamic> json) {
    return CitaDetalle(
      idCita: json['idCita'].toString(),
      estado: json['estado'] as String,
      fechaCreacion: DateTime.tryParse(json['fechaCreacion'] as String? ?? '') ??
          DateTime.now(),
      horario: HorarioCita.fromJson(json['horario'] as Map<String, dynamic>),
      especialidad:
          EspecialidadCita.fromJson(json['especialidad'] as Map<String, dynamic>),
      pago: json['pago'] != null
          ? PagoCita.fromJson(json['pago'] as Map<String, dynamic>)
          : null,
    );
  }
}

const _meses = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

String formatoDiaMesCita(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

String formatoHoraCita(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final ampm = f.hour < 12 ? 'AM' : 'PM';
  final min = f.minute.toString().padLeft(2, '0');
  return '$h:$min $ampm';
}

String formatoCompletoCita(DateTime f) =>
    '${formatoDiaMesCita(f)} · ${formatoHoraCita(f)}';

String etiquetaEstadoCita(String estado) {
  switch (estado) {
    case 'pendiente':
      return 'Pendiente';
    case 'confirmada':
      return 'Confirmada';
    case 'reprogramada':
      return 'Reprogramada';
    case 'cancelada':
      return 'Cancelada';
    default:
      return estado;
  }
}

IconData iconoParaEspecialidad(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('cardio')) return Icons.favorite;
  if (n.contains('dermat')) return Icons.healing;
  if (n.contains('nutri')) return Icons.restaurant_menu;
  if (n.contains('psico')) return Icons.psychology;
  return Icons.medical_services;
}

Color colorParaEspecialidad(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('cardio')) return AppColors.green;
  if (n.contains('dermat')) return AppColors.blue;
  if (n.contains('nutri')) return AppColors.amber;
  if (n.contains('psico')) return const Color(0xFF993556);
  return AppColors.gray600;
}

Color colorFondoParaEspecialidad(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('cardio')) return AppColors.greenLight;
  if (n.contains('dermat')) return AppColors.blueLight;
  if (n.contains('nutri')) return AppColors.amberLight;
  if (n.contains('psico')) return const Color(0xFFFBEAF0);
  return AppColors.gray50;
}
