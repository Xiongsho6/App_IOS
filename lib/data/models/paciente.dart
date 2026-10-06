
class Paciente {
  final String idPaciente;
  final String nombre;
  final String apellido;
  final String documento;
  final String correo;
  final String telefono;

  Paciente({
    required this.idPaciente,
    required this.nombre,
    required this.apellido,
    required this.documento,
    required this.correo,
    required this.telefono,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      idPaciente: json['id_paciente'] as String,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      documento: json['documento'] as String,
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
    );
  }

  factory Paciente.fromMap(Map<String, dynamic> map) {
    return Paciente(
      idPaciente: map['id_paciente'] as String,
      nombre: map['nombre'] as String,
      apellido: map['apellido'] as String,
      documento: map['documento'] as String,
      correo: map['correo'] as String,
      telefono: map['telefono'] as String,
    );
  }

  Map<String, dynamic> toCacheMap() => {
        'id_paciente': idPaciente,
        'nombre': nombre,
        'apellido': apellido,
        'documento': documento,
        'correo': correo,
        'telefono': telefono,
        'sincronizado_at': DateTime.now().toIso8601String(),
      };
}
