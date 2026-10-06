import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum MetodoPago { tarjeta, caja }

enum EstadoPago { ninguno, pendienteCaja, aprobado, rechazado }

class Especialidad {
  final String id;
  final String nombre;
  final int disponibles;
  final Color color;
  final Color colorFondo;
  final IconData icono;
  final int precio;

  const Especialidad({
    required this.id,
    required this.nombre,
    required this.disponibles,
    required this.color,
    required this.colorFondo,
    required this.icono,
    required this.precio,
  });
}

const List<Especialidad> especialidadesMock = [
  Especialidad(
    id: 'cardiologia',
    nombre: 'Cardiología',
    disponibles: 8,
    color: AppColors.green,
    colorFondo: AppColors.greenLight,
    icono: Icons.favorite,
    precio: 120,
  ),
  Especialidad(
    id: 'dermatologia',
    nombre: 'Dermatología',
    disponibles: 5,
    color: AppColors.blue,
    colorFondo: AppColors.blueLight,
    icono: Icons.healing,
    precio: 100,
  ),
  Especialidad(
    id: 'nutricion',
    nombre: 'Nutrición',
    disponibles: 12,
    color: AppColors.amber,
    colorFondo: AppColors.amberLight,
    icono: Icons.restaurant_menu,
    precio: 80,
  ),
  Especialidad(
    id: 'psicologia',
    nombre: 'Psicología',
    disponibles: 3,
    color: Color(0xFF993556),
    colorFondo: Color(0xFFFBEAF0),
    icono: Icons.psychology,
    precio: 110,
  ),
];

class Horario {
  final String hora;
  final bool ocupado;
  const Horario(this.hora, {this.ocupado = false});
}

List<Horario> horariosParaDia(DateTime dia) {
  const base = [
    '8:00 AM',
    '9:30 AM',
    '11:00 AM',
    '2:00 PM',
    '3:30 PM',
    '5:00 PM',
  ];
  final semilla = dia.day;
  return List.generate(base.length, (i) {
    final ocupado = (semilla + i) % 3 == 0;
    return Horario(base[i], ocupado: ocupado);
  });
}

String medicoParaEspecialidad(String especialidadId) {
  switch (especialidadId) {
    case 'cardiologia':
      return 'Dr. Carlos Meneses';
    case 'dermatologia':
      return 'Dra. Lucía Farfán';
    case 'nutricion':
      return 'Dr. Renzo Salcedo';
    case 'psicologia':
      return 'Dra. Ana Bravo';
    default:
      return 'Médico asignado';
  }
}

class CitaActiva {
  final String id;
  final Especialidad especialidad;
  final String medico;
  DateTime fecha;
  final String consultorio;
  EstadoPago estadoPago;
  String? tarjetaEnmascarada;
  String? comprobante;

  CitaActiva({
    required this.id,
    required this.especialidad,
    required this.medico,
    required this.fecha,
    required this.consultorio,
    required this.estadoPago,
    this.tarjetaEnmascarada,
    this.comprobante,
  });

  bool get tienePago =>
      estadoPago == EstadoPago.aprobado || estadoPago == EstadoPago.pendienteCaja;
}

class CitasMockStore {
  CitasMockStore._();
  static final CitasMockStore instance = CitasMockStore._();

  final List<CitaActiva> citas = [
    CitaActiva(
      id: 'c1',
      especialidad: especialidadesMock[0],
      medico: 'Dr. Carlos Meneses',
      fecha: DateTime.now().add(const Duration(days: 10, hours: 2)),
      consultorio: 'Piso 3, Cons. 12',
      estadoPago: EstadoPago.aprobado,
      tarjetaEnmascarada: '•••• 4521',
      comprobante: '#MC-2025-00847',
    ),
    CitaActiva(
      id: 'c2',
      especialidad: especialidadesMock[2],
      medico: 'Dr. Renzo Salcedo',
      fecha: DateTime.now().add(const Duration(days: 1, hours: 5)),
      consultorio: 'Piso 1, Cons. 3',
      estadoPago: EstadoPago.ninguno,
    ),
  ];

  void eliminar(String id) => citas.removeWhere((c) => c.id == id);
}

String formatoDiaMes(DateTime f) {
  const meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  return '${f.day} ${meses[f.month - 1]}';
}

String formatoHora(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final ampm = f.hour < 12 ? 'AM' : 'PM';
  final min = f.minute.toString().padLeft(2, '0');
  return '$h:$min $ampm';
}

String formatoCompleto(DateTime f) => '${formatoDiaMes(f)} · ${formatoHora(f)}';
