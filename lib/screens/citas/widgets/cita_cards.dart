import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cita.dart';

const _mesesCortos = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Tarjeta de una cita que se puede elegir (cancelar / reprogramar).
class CitaSeleccionableCard extends StatelessWidget {
  final CitaDetalle cita;
  final bool seleccionada;
  final Color colorAcento;
  final Color colorFondoSeleccion;
  final VoidCallback onTap;

  const CitaSeleccionableCard({
    super.key,
    required this.cita,
    required this.seleccionada,
    required this.colorAcento,
    required this.colorFondoSeleccion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = cita.fechaHoraCita;
    final pago = cita.pago;

    final (String textoPago, Color colorPago, Color fondoPago) = pago == null
        ? ('Sin pago', AppColors.gray600, AppColors.gray50)
        : pago.confirmado
            ? ('Pago confirmado', AppColors.greenDark, AppColors.greenLight)
            : pago.pendienteEnCaja
                ? (
                    'Pago pendiente en caja',
                    AppColors.amberDark,
                    AppColors.amberLight
                  )
                : ('Con pago registrado', AppColors.gray600, AppColors.gray50);

    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada ? colorFondoSeleccion : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: seleccionada ? colorAcento : AppColors.gray100,
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: seleccionada ? colorAcento : AppColors.gray400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${f.day}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text(_mesesCortos[f.month - 1],
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cita.especialidad.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          '${formatoHoraCita(f)} · ${cita.horario.consultorio}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.gray600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: fondoPago,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(textoPago,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorPago)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  seleccionada
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: seleccionada ? colorAcento : AppColors.gray200,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumen con cabecera de color y filas clave/valor.
class ResumenCitaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color colorCabecera;
  final Color colorTexto;
  final List<MapEntry<String, Widget>> filas;

  const ResumenCitaCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.colorCabecera,
    required this.colorTexto,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: colorCabecera,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: colorTexto, shape: BoxShape.circle),
                  child: Icon(icono, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colorTexto)),
                      const SizedBox(height: 2),
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.gray600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                for (int i = 0; i < filas.length; i++) ...[
                  Row(
                    children: [
                      Text(filas[i].key,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.gray600)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: filas[i].value,
                        ),
                      ),
                    ],
                  ),
                  if (i != filas.length - 1) const Divider(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío con ícono, mensaje y un botón.
class EstadoSinCitas extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color colorFondo;
  final String titulo;
  final String mensaje;
  final String textoBoton;
  final VoidCallback onPressed;

  const EstadoSinCitas({
    super.key,
    required this.icono,
    required this.color,
    required this.colorFondo,
    required this.titulo,
    required this.mensaje,
    required this.textoBoton,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration:
                  BoxDecoration(color: colorFondo, shape: BoxShape.circle),
              child: Icon(icono, color: color, size: 30),
            ),
            const SizedBox(height: 14),
            Text(titulo,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.gray600)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton(onPressed: onPressed, child: Text(textoBoton)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error de carga con botón de reintento.
class EstadoErrorCita extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const EstadoErrorCita({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.gray400),
          const SizedBox(height: 12),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 13)),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
