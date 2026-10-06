import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad_horario.dart';
import '../../data/repositories/citas_local_repository.dart';
import 'mock/citas_mock.dart' show MetodoPago;
import 'widgets/cita_cards.dart';
import 'widgets/citas_shared_widgets.dart';

class ReprogramarCitaScreen extends StatefulWidget {
  const ReprogramarCitaScreen({super.key});

  @override
  State<ReprogramarCitaScreen> createState() => _ReprogramarCitaScreenState();
}

enum _Vista { lista, nuevoHorario, agregarPago, confirmada }

const _spinnerBlanco = SizedBox(
  width: 20,
  height: 20,
  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
);

class _ReprogramarCitaScreenState extends State<ReprogramarCitaScreen> {
  static const _inicialesDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _meses = [
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

  final _repo = CitasLocalRepository();

  _Vista _vista = _Vista.lista;

  bool _cargandoCitas = true;
  String? _errorCitas;
  List<CitaDetalle> _citas = [];
  CitaDetalle? _seleccionada;
  DateTime? _fechaAnterior;

  DateTime? _nuevaFecha;
  bool _cargandoHorarios = false;
  String? _errorHorarios;
  List<HorarioApi> _horariosDelDia = [];
  HorarioApi? _nuevoHorario;

  MetodoPago? _metodoPago;
  final _numeroTarjetaCtrl = TextEditingController();
  final _vencimientoCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nombreTarjetaCtrl = TextEditingController();

  bool _enviando = false;
  String? _errorEnvio;
  CitaDetalle? _citaActualizada;

  @override
  void initState() {
    super.initState();
    _cargarCitas();
  }

  @override
  void dispose() {
    _numeroTarjetaCtrl.dispose();
    _vencimientoCtrl.dispose();
    _cvvCtrl.dispose();
    _nombreTarjetaCtrl.dispose();
    super.dispose();
  }

  String _mensajeError(Object e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }

  void _irAInicio() => context.go(AppRoutes.dashboard);

  /// Próximos 14 días a partir de mañana, sin domingos
  /// (los horarios de la base local no incluyen domingos).
  List<DateTime> get _diasDisponibles {
    final hoy = DateTime.now();
    final dias = <DateTime>[];
    var d = DateTime(hoy.year, hoy.month, hoy.day + 1);
    while (dias.length < 14) {
      if (d.weekday != DateTime.sunday) dias.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return dias;
  }

  void _atras() {
    if (_vista == _Vista.nuevoHorario) {
      setState(() {
        _vista = _Vista.lista;
        _errorEnvio = null;
      });
    } else if (_vista == _Vista.agregarPago) {
      setState(() {
        _vista = _Vista.nuevoHorario;
        _errorEnvio = null;
      });
    } else if (_vista == _Vista.confirmada) {
      _irAInicio();
    } else {
      context.pop();
    }
  }

  void _volverALista() => setState(() {
        _vista = _Vista.lista;
        _errorEnvio = null;
      });

  /// [silencioso] se usa al deslizar para refrescar: no reemplaza la lista
  /// por un spinner mientras carga.
  Future<void> _cargarCitas({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargandoCitas = true;
        _errorCitas = null;
      });
    }
    try {
      final lista = await _repo.listarMisCitas();
      if (!mounted) return;
      final activas = lista.where((c) => c.estado != 'cancelada').toList()
        ..sort((a, b) => a.fechaHoraCita.compareTo(b.fechaHoraCita));
      setState(() {
        _citas = activas;
        _errorCitas = null;
        if (_seleccionada != null &&
            !activas.any((c) => c.idCita == _seleccionada!.idCita)) {
          _seleccionada = null;
        }
        _cargandoCitas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCitas = _mensajeError(e);
        _cargandoCitas = false;
      });
    }
  }

  void _seleccionarCitaYContinuar() {
    if (_seleccionada == null) return;
    _fechaAnterior = _seleccionada!.fechaHoraCita;
    _nuevaFecha = _diasDisponibles.first;
    _nuevoHorario = null;
    _errorEnvio = null;
    setState(() => _vista = _Vista.nuevoHorario);
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    final fechaSolicitada = _nuevaFecha!;
    setState(() {
      _cargandoHorarios = true;
      _errorHorarios = null;
      _horariosDelDia = [];
      _nuevoHorario = null;
    });
    try {
      final lista = await _repo.listarHorarios(
        idEspecialidad: _seleccionada!.especialidad.idEspecialidad,
        fecha: fechaSolicitada,
      );
      // Si el usuario cambió de día mientras cargaba, se ignora esta respuesta.
      if (!mounted || _nuevaFecha != fechaSolicitada) return;
      setState(() {
        _horariosDelDia = lista;
        _cargandoHorarios = false;
      });
    } catch (e) {
      if (!mounted || _nuevaFecha != fechaSolicitada) return;
      setState(() {
        _errorHorarios = _mensajeError(e);
        _cargandoHorarios = false;
      });
    }
  }

  void _seleccionarDia(DateTime dia) {
    setState(() => _nuevaFecha = dia);
    _cargarHorarios();
  }

  void _continuarConNuevoHorario() {
    if (_seleccionada!.pago != null) {
      _aplicarReprogramacion();
    } else {
      setState(() {
        _errorEnvio = null;
        _vista = _Vista.agregarPago;
      });
    }
  }

  Future<void> _aplicarReprogramacion({MetodoPago? metodoParaPago}) async {
    if (_enviando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      final tarjetaPayload = metodoParaPago == MetodoPago.tarjeta
          ? {
              'numero': _numeroTarjetaCtrl.text.replaceAll(' ', ''),
              'titular': _nombreTarjetaCtrl.text.trim(),
              'vencimiento': _vencimientoCtrl.text.trim(),
            }
          : null;
      final cita = await _repo.reprogramarCita(
        idCita: _seleccionada!.idCita,
        idNuevoHorario: _nuevoHorario!.idHorario,
        metodoPago: metodoParaPago == null
            ? null
            : (metodoParaPago == MetodoPago.tarjeta ? 'tarjeta' : 'caja'),
        tarjeta: tarjetaPayload,
      );
      if (!mounted) return;
      setState(() {
        _citaActualizada = cita;
        _enviando = false;
        _vista = _Vista.confirmada;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEnvio = _mensajeError(e);
        _enviando = false;
      });
    }
  }

  bool _datosTarjetaCompletos() =>
      _numeroTarjetaCtrl.text.replaceAll(' ', '').length >= 12 &&
      _vencimientoCtrl.text.length == 5 &&
      _cvvCtrl.text.length >= 3 &&
      _nombreTarjetaCtrl.text.trim().isNotEmpty;

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatoDiaMesLocal(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final Widget pantalla = switch (_vista) {
      _Vista.lista => _pantallaLista(),
      _Vista.nuevoHorario => _pantallaNuevoHorario(),
      _Vista.agregarPago => _pantallaAgregarPago(),
      _Vista.confirmada => _pantallaConfirmada(),
    };

    return PopScope(
      // El botón "atrás" del sistema retrocede una vista en vez de salir.
      canPop: _vista == _Vista.lista,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _enviando) return;
        _atras();
      },
      child: pantalla,
    );
  }

  Widget _etiqueta(String texto) => Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.gray600,
        ),
      );

  Widget _valor(String texto, {Color? color, TextDecoration? decoracion}) =>
      Text(
        texto,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: decoracion,
        ),
      );

  // ───────────────────────── Lista ─────────────────────────

  Widget _pantallaLista() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.amber,
        titulo: 'Reprogramar cita',
        subtitulo: _cargandoCitas
            ? 'Cargando tus citas...'
            : _citas.isEmpty
                ? 'No tienes citas activas'
                : 'Selecciona la cita a modificar',
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _cargandoCitas
              ? const Center(child: CircularProgressIndicator())
              : _errorCitas != null && _citas.isEmpty
                  ? EstadoErrorCita(
                      mensaje: _errorCitas!, onReintentar: _cargarCitas)
                  : _citas.isEmpty
                      ? EstadoSinCitas(
                          icono: Icons.event_busy,
                          color: AppColors.amber,
                          colorFondo: AppColors.amberLight,
                          titulo: 'Sin citas activas',
                          mensaje:
                              'No tienes citas que puedas reprogramar en este momento.',
                          textoBoton: 'Volver al inicio',
                          onPressed: _irAInicio,
                        )
                      : _listaDeCitas(),
        ),
      ),
    );
  }

  Widget _listaDeCitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta('Tus citas activas'),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () => _cargarCitas(silencioso: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _citas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final cita = _citas[i];
                return CitaSeleccionableCard(
                  cita: cita,
                  seleccionada: _seleccionada?.idCita == cita.idCita,
                  colorAcento: AppColors.amber,
                  colorFondoSeleccion: AppColors.amberLight,
                  onTap: () => setState(() => _seleccionada = cita),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
          onPressed: _seleccionada == null ? null : _seleccionarCitaYContinuar,
          icon: const Icon(Icons.update, size: 18),
          label: Text(_seleccionada == null
              ? 'Selecciona una cita'
              : 'Elegir nuevo horario'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: _irAInicio, child: const Text('Volver al inicio')),
      ],
    );
  }

  // ───────────────────── Nuevo horario ─────────────────────

  Widget _pantallaNuevoHorario() {
    final cita = _seleccionada!;
    final dias = _diasDisponibles;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.amber,
        titulo: 'Nuevo horario',
        subtitulo: '${cita.especialidad.nombre} — elige otra fecha',
        onBack: _atras,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.amberDark),
                          children: [
                            const TextSpan(text: 'Cita actual: '),
                            TextSpan(
                              text: formatoCompletoCita(_fechaAnterior!),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_errorEnvio != null) ...[
                AvisoCard.error(titulo: _errorEnvio!),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _etiqueta('Elige una fecha'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 82,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: dias.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final d = dias[i];
                            final sel = _nuevaFecha != null &&
                                _mismoDia(d, _nuevaFecha!);
                            return Material(
                              color: sel ? AppColors.amber : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color:
                                      sel ? AppColors.amber : AppColors.gray200,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _seleccionarDia(d),
                                child: SizedBox(
                                  width: 54,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_inicialesDias[d.weekday - 1],
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: sel
                                                  ? Colors.white70
                                                  : AppColors.gray600)),
                                      const SizedBox(height: 3),
                                      Text('${d.day}',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? Colors.white
                                                  : AppColors.gray900)),
                                      const SizedBox(height: 1),
                                      Text(_meses[d.month - 1],
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: sel
                                                  ? Colors.white70
                                                  : AppColors.gray400)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _etiqueta(_nuevaFecha == null
                          ? 'Turnos disponibles'
                          : 'Turnos disponibles — ${_formatoDiaMesLocal(_nuevaFecha!)}'),
                      const SizedBox(height: 8),
                      if (_cargandoHorarios)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorHorarios != null)
                        EstadoErrorCita(
                            mensaje: _errorHorarios!,
                            onReintentar: _cargarHorarios)
                      else if (_horariosDelDia.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No hay turnos disponibles este día. Prueba otra fecha.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.gray600),
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
                          children: _horariosDelDia.map((h) {
                            final sel = _nuevoHorario?.idHorario == h.idHorario;
                            return Material(
                              color: sel ? AppColors.amber : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                      sel ? AppColors.amber : AppColors.gray200,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => setState(() => _nuevoHorario = h),
                                child: Center(
                                  child: Text(
                                    h.horaFormateada,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.gray600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
                onPressed: _nuevoHorario == null || _enviando
                    ? null
                    : _continuarConNuevoHorario,
                child: _enviando
                    ? _spinnerBlanco
                    : Text(_nuevoHorario == null
                        ? 'Elige un turno disponible'
                        : 'Continuar con ${_nuevoHorario!.horaFormateada}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── Agregar pago ─────────────────────

  Widget _campoLabel(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(texto,
            style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
      );

  Widget _pantallaAgregarPago() {
    final cita = _seleccionada!;
    final precio = cita.especialidad.precio;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.amber,
        titulo: 'Agregar pago',
        subtitulo: 'Esta cita no tiene pago registrado',
        onBack: _atras,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorEnvio != null) ...[
                AvisoCard.error(titulo: _errorEnvio!),
                const SizedBox(height: 10),
              ],
              const AvisoCard.advertencia(
                titulo: 'Pago pendiente',
                subtitulo:
                    'Para confirmar la reprogramación debes registrar el pago ahora o en caja.',
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gray100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${cita.especialidad.nombre} · ${cita.especialidad.medico}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatoDiaMesLocal(_nuevaFecha!)} · ${_nuevoHorario!.horaFormateada}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.gray600),
                          ),
                        ],
                      ),
                    ),
                    Text('S/ ${precio.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.amber)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _etiqueta('Método de pago'),
              const SizedBox(height: 6),
              PayOptionTile(
                icono: Icons.credit_card,
                colorIcono: AppColors.blue,
                colorFondoIcono: AppColors.blueLight,
                titulo: 'Tarjeta',
                subtitulo: 'Visa, Mastercard',
                seleccionado: _metodoPago == MetodoPago.tarjeta,
                colorSeleccion: AppColors.blue,
                onTap: () => setState(() => _metodoPago = MetodoPago.tarjeta),
              ),
              PayOptionTile(
                icono: Icons.storefront,
                colorIcono: AppColors.amber,
                colorFondoIcono: AppColors.amberLight,
                titulo: 'Pagar en caja',
                subtitulo: 'El día de la cita',
                seleccionado: _metodoPago == MetodoPago.caja,
                colorSeleccion: AppColors.amber,
                onTap: () => setState(() => _metodoPago = MetodoPago.caja),
              ),
              if (_metodoPago == MetodoPago.tarjeta) ...[
                const SizedBox(height: 6),
                _campoLabel('Número de tarjeta'),
                TextField(
                  controller: _numeroTarjetaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [TarjetaFormatter()],
                  autofillHints: const [AutofillHints.creditCardNumber],
                  decoration:
                      const InputDecoration(hintText: '4521 0000 0000 0000'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campoLabel('Vencimiento'),
                          TextField(
                            controller: _vencimientoCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [VencimientoFormatter()],
                            decoration:
                                const InputDecoration(hintText: 'MM/AA'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campoLabel('CVV'),
                          TextField(
                            controller: _cvvCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            obscureText: true,
                            decoration: const InputDecoration(hintText: '•••'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _campoLabel('Nombre en la tarjeta'),
                TextField(
                  controller: _nombreTarjetaCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(hintText: 'JUAN PEREZ TORRES'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _metodoPago == MetodoPago.tarjeta
                      ? AppColors.blue
                      : AppColors.amber,
                ),
                onPressed: _enviando || _metodoPago == null
                    ? null
                    : _metodoPago == MetodoPago.caja
                        ? () => _aplicarReprogramacion(
                            metodoParaPago: MetodoPago.caja)
                        : _datosTarjetaCompletos()
                            ? () => _aplicarReprogramacion(
                                metodoParaPago: MetodoPago.tarjeta)
                            : null,
                child: _enviando
                    ? _spinnerBlanco
                    : Text(_metodoPago == null
                        ? 'Elige cómo pagar'
                        : _metodoPago == MetodoPago.caja
                            ? 'Confirmar reprogramación'
                            : 'Pagar con tarjeta S/ ${precio.toStringAsFixed(0)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _enviando ? null : _volverALista,
                child: const Text('Cancelar reprogramación'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── Confirmada ─────────────────────

  Widget _pantallaConfirmada() {
    final citaOriginal = _seleccionada!;
    final citaNueva = _citaActualizada!;
    final esPendienteCaja =
        citaNueva.pago != null && citaNueva.pago!.pendienteEnCaja;
    final tienePago = citaNueva.pago != null;
    final id = citaNueva.idCita;
    final idCorto = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;

    return ResultadoScreen(
      color: esPendienteCaja ? AppColors.amber : AppColors.green,
      icono: Icons.check_circle,
      titulo: '¡Cita reprogramada!',
      subtitulo: esPendienteCaja
          ? 'Pago pendiente · pagar en caja'
          : tienePago
              ? 'Comprobante actualizado enviado'
              : 'Tu nuevo horario ya está registrado',
      children: [
        ResumenCitaCard(
          icono: iconoParaEspecialidad(citaNueva.especialidad.nombre),
          titulo: citaNueva.especialidad.nombre,
          subtitulo: formatoCompletoCita(citaNueva.fechaHoraCita),
          colorCabecera:
              esPendienteCaja ? AppColors.amberLight : AppColors.greenLight,
          colorTexto: esPendienteCaja ? AppColors.amberDark : AppColors.green,
          filas: [
            MapEntry(
              'Fecha anterior',
              _valor(
                formatoCompletoCita(citaOriginal.fechaHoraCita),
                color: AppColors.gray600,
                decoracion: TextDecoration.lineThrough,
              ),
            ),
            MapEntry('Médico', _valor(citaNueva.especialidad.medico)),
            MapEntry('Consultorio', _valor(citaNueva.horario.consultorio)),
            MapEntry(
              'Pago',
              _valor(
                esPendienteCaja
                    ? '⏳ Pendiente · S/ ${citaNueva.especialidad.precio.toStringAsFixed(0)}'
                    : '✓ Ya registrado',
                color: esPendienteCaja ? AppColors.amber : AppColors.green,
              ),
            ),
            MapEntry('Cita', _valor('#$idCorto')),
          ],
        ),
        const SizedBox(height: 12),
        esPendienteCaja
            ? const AvisoCard.advertencia(
                titulo: 'El día de la cita',
                subtitulo:
                    'Llega 15 min antes y paga en Caja Central · muestra tu DNI.')
            : const AvisoCard.exito(
                titulo: 'Comprobante actualizado enviado a tu correo.'),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: _irAInicio, child: const Text('Ir al inicio')),
      ],
    );
  }
}
