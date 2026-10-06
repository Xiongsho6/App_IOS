
library;

class ReintegroInfo {
  final double monto;
  final int porcentaje;

  const ReintegroInfo({required this.monto, required this.porcentaje});

  factory ReintegroInfo.fromJson(Map<String, dynamic> json) {
    return ReintegroInfo(
      monto: (json['monto'] as num).toDouble(),
      porcentaje: (json['porcentaje'] as num).toInt(),
    );
  }
}

class CancelacionResultado {
  final String estado;
  final ReintegroInfo? reintegro;

  const CancelacionResultado({required this.estado, this.reintegro});

  bool get huboReintegro => reintegro != null;

  factory CancelacionResultado.fromJson(Map<String, dynamic> json) {
    return CancelacionResultado(
      estado: json['estado'] as String,
      reintegro: json['reintegro'] != null
          ? ReintegroInfo.fromJson(json['reintegro'] as Map<String, dynamic>)
          : null,
    );
  }
}
