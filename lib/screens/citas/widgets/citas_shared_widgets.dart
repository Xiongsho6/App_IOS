import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../mock/citas_mock.dart';

class StepDots extends StatelessWidget {
  final int total;
  final int actual;
  final Color colorActivo;

  const StepDots({
    super.key,
    required this.total,
    required this.actual,
    this.colorActivo = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < actual;
        final active = i == actual;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? colorActivo
                  : done
                      ? colorActivo.withValues(alpha: 0.7)
                      : colorActivo.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class CitasHeader extends StatelessWidget implements PreferredSizeWidget {
  final Color color;
  final String titulo;
  final String subtitulo;
  final Widget? stepBar;
  final VoidCallback? onBack;

  const CitasHeader({
    super.key,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    this.stepBar,
    this.onBack,
  });

  // El color ahora cubre también la barra de estado, así que la altura
  // total debe incluir ese espacio superior.
  static double get _insetSuperior => MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first,
      ).padding.top;

  @override
  Size get preferredSize =>
      Size.fromHeight(_insetSuperior + (stepBar != null ? 134 : 114));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: color,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 40),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      if (stepBar != null) ...[
                        const SizedBox(height: 12),
                        stepBar!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarioYTurnos extends StatefulWidget {
  final Color colorAcento;
  final void Function(DateTime dia, Horario horario) onSeleccion;

  const CalendarioYTurnos({
    super.key,
    required this.colorAcento,
    required this.onSeleccion,
  });

  @override
  State<CalendarioYTurnos> createState() => _CalendarioYTurnosState();
}

class _CalendarioYTurnosState extends State<CalendarioYTurnos> {
  static const _iniciales = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late DateTime _diaSeleccionado;
  Horario? _horarioSeleccionado;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _diaSeleccionado = DateTime(hoy.year, hoy.month, hoy.day + 1);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final dias =
        List.generate(14, (i) => DateTime(hoy.year, hoy.month, hoy.day + i));
    final horarios = horariosParaDia(_diaSeleccionado);
    final etiqueta = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontSize: 12, letterSpacing: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elige una fecha', style: etiqueta),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = dias[i];
              final sel = _mismoDia(d, _diaSeleccionado);
              return GestureDetector(
                onTap: () => setState(() {
                  _diaSeleccionado = d;
                  _horarioSeleccionado = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 50,
                  decoration: BoxDecoration(
                    color: sel ? widget.colorAcento : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? widget.colorAcento : AppColors.gray200,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _iniciales[d.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white70 : AppColors.gray400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.gray900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text('Turnos disponibles — ${formatoDiaMes(_diaSeleccionado)}',
            style: etiqueta),
        const SizedBox(height: 10),
        if (horarios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No hay turnos para este día. Prueba otra fecha.',
              style: TextStyle(fontSize: 13, color: AppColors.gray400),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: horarios.map((h) {
              final sel = _horarioSeleccionado?.hora == h.hora;
              return GestureDetector(
                onTap: h.ocupado
                    ? null
                    : () {
                        setState(() => _horarioSeleccionado = h);
                        widget.onSeleccion(_diaSeleccionado, h);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: h.ocupado
                        ? AppColors.gray50
                        : sel
                            ? widget.colorAcento
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: h.ocupado
                          ? AppColors.gray100
                          : sel
                              ? widget.colorAcento
                              : AppColors.gray200,
                    ),
                  ),
                  child: Text(
                    h.hora,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: h.ocupado ? TextDecoration.lineThrough : null,
                      color: h.ocupado
                          ? AppColors.textoDeshabilitado
                          : sel
                              ? Colors.white
                              : AppColors.gray600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const _Leyenda(
                color: Colors.white,
                borde: AppColors.gray200,
                texto: 'Disponible'),
            const SizedBox(width: 14),
            const _Leyenda(
                color: AppColors.gray50,
                borde: AppColors.gray100,
                texto: 'Ocupado'),
            const SizedBox(width: 14),
            _Leyenda(
                color: widget.colorAcento,
                borde: widget.colorAcento,
                texto: 'Elegido'),
          ],
        ),
      ],
    );
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final Color borde;
  final String texto;
  const _Leyenda(
      {required this.color, required this.borde, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borde),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(texto,
            style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
      ],
    );
  }
}

class PayOptionTile extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final Color colorFondoIcono;
  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final Color colorSeleccion;
  final VoidCallback onTap;

  const PayOptionTile({
    super.key,
    required this.icono,
    required this.colorIcono,
    required this.colorFondoIcono,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionado,
    required this.onTap,
    this.colorSeleccion = AppColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: '$titulo, $subtitulo',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: seleccionado
              ? colorSeleccion.withValues(alpha: 0.08)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: seleccionado ? colorSeleccion : AppColors.gray100,
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorFondoIcono,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, color: colorIcono, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(subtitulo,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.gray600)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            seleccionado ? colorSeleccion : AppColors.gray200,
                        width: 2,
                      ),
                      color: seleccionado ? colorSeleccion : Colors.transparent,
                    ),
                    child: seleccionado
                        ? const Icon(Icons.circle, size: 8, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CitaResumenCard extends StatelessWidget {
  final Especialidad especialidad;
  final String medico;
  final DateTime fecha;
  final List<MapEntry<String, Widget>> filas;
  final Color colorCabecera;
  final Color colorTextoCabecera;

  const CitaResumenCard({
    super.key,
    required this.especialidad,
    required this.medico,
    required this.fecha,
    required this.filas,
    this.colorCabecera = AppColors.greenLight,
    this.colorTextoCabecera = AppColors.green,
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
                  decoration: BoxDecoration(
                    color: colorTextoCabecera,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(especialidad.icono, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(especialidad.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colorTextoCabecera)),
                      const SizedBox(height: 2),
                      Text(formatoCompleto(fecha),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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

class AvisoCard extends StatelessWidget {
  final Color colorFondo;
  final Color colorTexto;
  final String titulo;
  final String? subtitulo;
  final IconData? icono;

  const AvisoCard({
    super.key,
    required this.colorFondo,
    required this.colorTexto,
    required this.titulo,
    this.subtitulo,
    this.icono,
  });

  const AvisoCard.exito({super.key, required this.titulo, this.subtitulo})
      : colorFondo = AppColors.greenLight,
        colorTexto = AppColors.greenDark,
        icono = Icons.check_circle_outline;

  const AvisoCard.advertencia({super.key, required this.titulo, this.subtitulo})
      : colorFondo = AppColors.amberLight,
        colorTexto = AppColors.amberDark,
        icono = Icons.info_outline;

  const AvisoCard.error({super.key, required this.titulo, this.subtitulo})
      : colorFondo = AppColors.redLight,
        colorTexto = AppColors.redDark,
        icono = Icons.error_outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 18, color: colorTexto),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorTexto)),
                if (subtitulo != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitulo!,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorTexto.withValues(alpha: 0.9))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultadoScreen extends StatelessWidget {
  final Color color;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  const ResultadoScreen({
    super.key,
    required this.color,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: color,
              padding: EdgeInsets.fromLTRB(16, topInset + 18, 16, 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subtitulo,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
