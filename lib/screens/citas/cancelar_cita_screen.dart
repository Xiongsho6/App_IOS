import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/cancelacion.dart';
import '../../data/models/cita.dart';
import '../../data/repositories/citas_local_repository.dart';
import 'widgets/cita_cards.dart';
import 'widgets/citas_shared_widgets.dart';

class CancelarCitaScreen extends StatefulWidget {
  const CancelarCitaScreen({super.key});

  @override
  State<CancelarCitaScreen> createState() => _CancelarCitaScreenState();
}

enum _Vista { lista, confirmar, exito }

const _spinnerBlanco = SizedBox(
  width: 20,
  height: 20,
  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
);

class _CancelarCitaScreenState extends State<CancelarCitaScreen> {
  final _repo = CitasLocalRepository();

  _Vista _vista = _Vista.lista;

  bool _cargando = true;
  String? _errorCarga;
  List<CitaDetalle> _citas = [];
  CitaDetalle? _seleccionada;

  bool _enviando = false;
  String? _errorEnvio;

  final _cuentaCtrl = TextEditingController();
  final _titularCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();

  CancelacionResultado? _resultado;

  @override
  void initState() {
    super.initState();
    _cargarCitas();
  }

  @override
  void dispose() {
    _cuentaCtrl.dispose();
    _titularCtrl.dispose();
    _bancoCtrl.dispose();
    super.dispose();
  }

  String _mensajeError(Object e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }

  /// [silencioso] se usa al deslizar para refrescar: no reemplaza la lista
  /// por un spinner mientras carga.
  Future<void> _cargarCitas({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _errorCarga = null;
      });
    }
    try {
      final lista = await _repo.listarMisCitas();
      if (!mounted) return;
      final activas = lista.where((c) => c.estado != 'cancelada').toList()
        ..sort((a, b) => a.fechaHoraCita.compareTo(b.fechaHoraCita));
      setState(() {
        _citas = activas;
        _errorCarga = null;
        // Si la cita elegida ya no existe tras refrescar, se deselecciona.
        if (_seleccionada != null &&
            !activas.any((c) => c.idCita == _seleccionada!.idCita)) {
          _seleccionada = null;
        }
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = _mensajeError(e);
        _cargando = false;
      });
    }
  }

  void _irAInicio() => context.go(AppRoutes.dashboard);

  void _volverALista() => setState(() {
        _vista = _Vista.lista;
        _errorEnvio = null;
      });

  bool get _tienePago => _seleccionada?.pago?.confirmado ?? false;

  bool get _pagoPendiente => _seleccionada?.pago?.pendienteEnCaja ?? false;

  bool get _reintegroTotalEstimado =>
      _seleccionada != null &&
      _seleccionada!.fechaHoraCita.difference(DateTime.now()).inHours > 48;

  double get _montoPagadoEstimado => _seleccionada?.pago?.monto ?? 0;

  double get _montoReintegroEstimado => _reintegroTotalEstimado
      ? _montoPagadoEstimado
      : (_montoPagadoEstimado * 0.5);

  void _seleccionarCitaYContinuar() {
    if (_seleccionada == null) return;
    setState(() {
      _errorEnvio = null;
      _vista = _Vista.confirmar;
    });
  }

  Future<void> _cancelar({Map<String, String>? cuentaBancaria}) async {
    if (_enviando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      final resultado = await _repo.cancelarCita(
        idCita: _seleccionada!.idCita,
        cuentaBancaria: cuentaBancaria,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _enviando = false;
        _vista = _Vista.exito;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEnvio = _mensajeError(e);
        _enviando = false;
      });
    }
  }

  void _confirmarConPago() {
    final numero = _cuentaCtrl.text.replaceAll(' ', '');
    final titular = _titularCtrl.text.trim();
    final banco = _bancoCtrl.text.trim();

    if (!RegExp(r'^\d{10,20}$').hasMatch(numero)) {
      setState(() =>
          _errorEnvio = 'El número de cuenta debe tener entre 10 y 20 dígitos');
      return;
    }
    if (titular.isEmpty || banco.isEmpty) {
      setState(
          () => _errorEnvio = 'Completa el titular y el banco de la cuenta');
      return;
    }
    _cancelar(cuentaBancaria: {
      'numero': numero,
      'titular': titular,
      'banco': banco,
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget pantalla = switch (_vista) {
      _Vista.lista => _pantallaLista(),
      _Vista.confirmar =>
        _tienePago ? _pantallaConfirmarConPago() : _pantallaConfirmarSinPago(),
      _Vista.exito => _pantallaExito(),
    };

    return PopScope(
      // El botón "atrás" del sistema retrocede una vista en vez de salir.
      canPop: _vista == _Vista.lista,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _enviando) return;
        if (_vista == _Vista.exito) {
          _irAInicio();
        } else {
          _volverALista();
        }
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

  Widget _valor(String texto, {Color? color, bool fuerte = false}) => Text(
        texto,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          fontWeight: fuerte ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      );

  // ───────────────────────── Lista ─────────────────────────

  Widget _pantallaLista() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.red,
        titulo: 'Cancelar cita',
        subtitulo: _cargando
            ? 'Cargando tus citas...'
            : _citas.isEmpty
                ? 'No tienes citas activas'
                : 'Selecciona la cita a cancelar',
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _errorCarga != null && _citas.isEmpty
                  ? EstadoErrorCita(
                      mensaje: _errorCarga!, onReintentar: _cargarCitas)
                  : _citas.isEmpty
                      ? EstadoSinCitas(
                          icono: Icons.event_busy,
                          color: AppColors.red,
                          colorFondo: AppColors.redLight,
                          titulo: 'Sin citas activas',
                          mensaje:
                              'No tienes citas que puedas cancelar en este momento.',
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
            color: AppColors.red,
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
                  colorAcento: AppColors.red,
                  colorFondoSeleccion: AppColors.redLight,
                  onTap: () => setState(() => _seleccionada = cita),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: _seleccionada == null ? null : _seleccionarCitaYContinuar,
          icon: const Icon(Icons.close, size: 18),
          label: Text(_seleccionada == null
              ? 'Selecciona una cita'
              : 'Cancelar cita seleccionada'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: _irAInicio, child: const Text('Volver al inicio')),
      ],
    );
  }

  // ───────────────────── Confirmar (sin pago) ─────────────────────

  Widget _pantallaConfirmarSinPago() {
    final cita = _seleccionada!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.red,
        titulo: 'Confirmar cancelación',
        subtitulo: _pagoPendiente
            ? 'Tu pago seguía pendiente en caja'
            : 'Esta cita no tiene pago confirmado',
        onBack: _volverALista,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorEnvio != null) ...[
                AvisoCard.error(titulo: _errorEnvio!),
                const SizedBox(height: 10),
              ],
              ResumenCitaCard(
                icono: iconoParaEspecialidad(cita.especialidad.nombre),
                titulo: cita.especialidad.nombre,
                subtitulo: formatoCompletoCita(cita.fechaHoraCita),
                colorCabecera: AppColors.redLight,
                colorTexto: AppColors.redDark,
                filas: [
                  MapEntry('Médico', _valor(cita.especialidad.medico)),
                  MapEntry('Consultorio', _valor(cita.horario.consultorio)),
                  MapEntry('Reintegro', _valor('No aplica')),
                ],
              ),
              const SizedBox(height: 12),
              const AvisoCard.advertencia(
                titulo: 'Esta cita dejará de estar activa',
                subtitulo:
                    'Una vez cancelada, ya no aparecerá en tus citas activas.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: _enviando ? null : () => _cancelar(),
                child: _enviando
                    ? _spinnerBlanco
                    : const Text('Confirmar cancelación'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _enviando ? null : _volverALista,
                child: const Text('No cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── Confirmar (con pago) ─────────────────────

  Widget _pantallaConfirmarConPago() {
    final cita = _seleccionada!;
    final total = _reintegroTotalEstimado;
    final penalizacion = _montoPagadoEstimado - _montoReintegroEstimado;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.red,
        titulo: 'Confirmar cancelación',
        subtitulo: total
            ? 'Más de 48 h de anticipación — reintegro total'
            : '48 h o menos — reintegro del 50%',
        onBack: _volverALista,
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
              total
                  ? const AvisoCard.exito(
                      titulo: 'Cancelas con anticipación',
                      subtitulo: 'Recibirás el 100% de reintegro.')
                  : const AvisoCard.advertencia(
                      titulo: 'Cancelación tardía',
                      subtitulo:
                          'Por cancelar con 48 h o menos de anticipación, solo recibirás el 50% de reintegro.'),
              const SizedBox(height: 12),
              ResumenCitaCard(
                icono: iconoParaEspecialidad(cita.especialidad.nombre),
                titulo: cita.especialidad.nombre,
                subtitulo: formatoCompletoCita(cita.fechaHoraCita),
                colorCabecera: AppColors.redLight,
                colorTexto: AppColors.redDark,
                filas: [
                  MapEntry('Pagado',
                      _valor('S/ ${_montoPagadoEstimado.toStringAsFixed(2)}')),
                  if (!total)
                    MapEntry(
                      'Penalización',
                      _valor('S/ ${penalizacion.toStringAsFixed(2)} (50%)',
                          color: AppColors.red),
                    ),
                  MapEntry(
                    total ? 'Reintegro estimado' : 'Recibirás (estimado)',
                    _valor(
                      'S/ ${_montoReintegroEstimado.toStringAsFixed(2)} (${total ? '100' : '50'}%)',
                      color: AppColors.green,
                      fuerte: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _etiqueta('Cuenta bancaria para el reintegro'),
              const SizedBox(height: 8),
              TextField(
                controller: _cuentaCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Número de cuenta',
                  hintText: 'Entre 10 y 20 dígitos',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titularCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Titular de la cuenta'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bancoCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_enviando) _confirmarConPago();
                },
                decoration: const InputDecoration(labelText: 'Banco'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: _enviando ? null : _confirmarConPago,
                child: _enviando
                    ? _spinnerBlanco
                    : Text(total
                        ? 'Confirmar cancelación y reintegro'
                        : 'Confirmar y procesar reintegro 50%'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _enviando ? null : _volverALista,
                child: const Text('No cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Éxito ─────────────────────────

  Widget _pantallaExito() {
    final cita = _seleccionada!;
    final reintegro = _resultado?.reintegro;
    final huboReintegro = reintegro != null;
    final cuenta = _cuentaCtrl.text.replaceAll(' ', '');
    final ultimos4 =
        cuenta.length >= 4 ? cuenta.substring(cuenta.length - 4) : '';

    return ResultadoScreen(
      color: AppColors.red,
      icono: Icons.check_circle,
      titulo: huboReintegro ? 'Reintegro iniciado' : 'Cita cancelada',
      subtitulo: huboReintegro
          ? 'El proceso puede tardar 2-3 días hábiles'
          : 'Sin pago confirmado · sin reintegro',
      children: [
        ResumenCitaCard(
          icono: iconoParaEspecialidad(cita.especialidad.nombre),
          titulo: cita.especialidad.nombre,
          subtitulo: formatoCompletoCita(cita.fechaHoraCita),
          colorCabecera:
              huboReintegro ? AppColors.greenLight : AppColors.gray50,
          colorTexto: huboReintegro ? AppColors.green : AppColors.gray600,
          filas: huboReintegro
              ? [
                  MapEntry(
                    'Monto',
                    _valor(
                      'S/ ${reintegro.monto.toStringAsFixed(2)} (${reintegro.porcentaje}%)',
                      color: AppColors.green,
                      fuerte: true,
                    ),
                  ),
                  MapEntry('Cuenta destino', _valor('•••• $ultimos4')),
                  MapEntry('Plazo', _valor('2-3 días hábiles')),
                ]
              : [
                  MapEntry('Estado', _valor('Cancelada', color: AppColors.red)),
                  MapEntry('Reintegro', _valor('No aplica')),
                ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: _irAInicio, child: const Text('Ir al inicio')),
      ],
    );
  }
}
