import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad_horario.dart';
import '../../data/repositories/citas_local_repository.dart';
import 'mock/citas_mock.dart' show MetodoPago;
import 'widgets/citas_shared_widgets.dart';

class NuevaCitaScreen extends StatefulWidget {
  final EspecialidadApi? especialidadInicial;
  const NuevaCitaScreen({super.key, this.especialidadInicial});

  @override
  State<NuevaCitaScreen> createState() => _NuevaCitaScreenState();
}

enum _Paso { especialidad, horario, pago, procesando, confirmacion, rechazo }

/// Da formato "1234 5678 9012 3456" mientras se escribe.
class _TarjetaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    var digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 16) digitos = digitos.substring(0, 16);
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digitos[i]);
    }
    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Da formato "MM/AA" mientras se escribe.
class _VencimientoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    var digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 4) digitos = digitos.substring(0, 4);
    final texto = digitos.length >= 3
        ? '${digitos.substring(0, 2)}/${digitos.substring(2)}'
        : digitos;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class _NuevaCitaScreenState extends State<NuevaCitaScreen> {
  final _repo = CitasLocalRepository();

  _Paso _paso = _Paso.especialidad;

  bool _cargandoEspecialidades = true;
  String? _errorEspecialidades;
  List<EspecialidadApi> _especialidades = [];
  EspecialidadApi? _especialidad;
  String _busquedaEspecialidad = '';

  DateTime? _fecha;
  late DateTime _mesVisible;
  bool _cargandoHorarios = false;
  String? _errorHorarios;
  List<HorarioApi> _horariosDelDia = [];
  HorarioApi? _horario;

  MetodoPago? _metodoPago;

  final _numeroTarjetaCtrl = TextEditingController();
  final _vencimientoCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nombreTarjetaCtrl = TextEditingController();

  CitaDetalle? _citaCreada;
  PagoResultado? _pagoResultado;
  String? _errorEnvio;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month, 1);
    _cargarEspecialidades();
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

  String? _codigoError(Object e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).code;
    }
    return null;
  }

  Future<void> _cargarEspecialidades() async {
    setState(() {
      _cargandoEspecialidades = true;
      _errorEspecialidades = null;
    });
    try {
      final lista = await _repo.listarEspecialidades();
      if (!mounted) return;
      setState(() {
        _especialidades = lista;
        _cargandoEspecialidades = false;
      });

      // Si llegamos desde el inicio con una especialidad ya elegida,
      // saltamos directo al paso de horario.
      final inicial = widget.especialidadInicial;
      if (inicial != null && _especialidad == null) {
        final coincidencias =
            lista.where((x) => x.idEspecialidad == inicial.idEspecialidad);
        if (coincidencias.isNotEmpty) {
          _especialidad = coincidencias.first;
          _avanzarAHorario();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEspecialidades = _mensajeError(e);
        _cargandoEspecialidades = false;
      });
    }
  }

  Future<void> _cargarHorarios() async {
    final fechaSolicitada = _fecha!;
    setState(() {
      _cargandoHorarios = true;
      _errorHorarios = null;
      _horariosDelDia = [];
    });
    try {
      final lista = await _repo.listarHorarios(
        idEspecialidad: _especialidad!.idEspecialidad,
        fecha: fechaSolicitada,
      );
      // Si el usuario cambió de día mientras cargaba, ignoramos esta respuesta.
      if (!mounted || _fecha != fechaSolicitada) return;
      setState(() {
        _horariosDelDia = lista;
        _cargandoHorarios = false;
      });
    } catch (e) {
      if (!mounted || _fecha != fechaSolicitada) return;
      setState(() {
        _errorHorarios = _mensajeError(e);
        _cargandoHorarios = false;
      });
    }
  }

  void _avanzarAHorario() {
    final hoy = DateTime.now();
    var primera = DateTime(hoy.year, hoy.month, hoy.day + 1);
    // Los horarios semilla no incluyen domingos.
    if (primera.weekday == DateTime.sunday) {
      primera = DateTime(primera.year, primera.month, primera.day + 1);
    }
    _fecha = primera;
    _mesVisible = DateTime(primera.year, primera.month, 1);
    _horario = null; // evita arrastrar un turno de otra especialidad
    setState(() => _paso = _Paso.horario);
    _cargarHorarios();
  }

  void _seleccionarDia(DateTime dia) {
    setState(() {
      _fecha = dia;
      _horario = null;
    });
    _cargarHorarios();
  }

  int get _pasoStepBar {
    switch (_paso) {
      case _Paso.especialidad:
        return 0;
      case _Paso.horario:
        return 1;
      default:
        return 2;
    }
  }

  void _irAInicio() => context.go(AppRoutes.dashboard);

  void _atras() {
    if (_paso == _Paso.horario) {
      setState(() => _paso = _Paso.especialidad);
    } else if (_paso == _Paso.pago) {
      setState(() => _paso = _Paso.horario);
    } else {
      context.pop();
    }
  }

  Future<void> _confirmarCitaYPago() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _paso = _Paso.procesando;
      _errorEnvio = null;
    });

    if (_citaCreada == null) {
      try {
        _citaCreada = await _repo.crearCita(_horario!.idHorario);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorEnvio = _mensajeError(e);
          _paso = _Paso.horario;
        });
        return;
      }
    }

    try {
      final tarjetaPayload = _metodoPago == MetodoPago.tarjeta
          ? {
              'numero': _numeroTarjetaCtrl.text.replaceAll(' ', ''),
              'titular': _nombreTarjetaCtrl.text.trim(),
              'vencimiento': _vencimientoCtrl.text.trim(),
            }
          : null;
      _pagoResultado = await _repo.registrarPago(
        idCita: _citaCreada!.idCita,
        metodo: _metodoPago == MetodoPago.tarjeta ? 'tarjeta' : 'caja',
        tarjeta: tarjetaPayload,
      );
      if (!mounted) return;
      setState(() => _paso = _Paso.confirmacion);
    } catch (e) {
      if (!mounted) return;
      if (_codigoError(e) == 'TARJETA_RECHAZADA') {
        setState(() => _paso = _Paso.rechazo);
      } else {
        setState(() {
          _errorEnvio = _mensajeError(e);
          _paso = _Paso.pago;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_paso) {
      case _Paso.confirmacion:
        return _pantallaConfirmacion();
      case _Paso.rechazo:
        return _pantallaRechazo();
      case _Paso.procesando:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      default:
        return _pantallaPasos();
    }
  }

  Widget _etiqueta(String texto) => Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.gray600,
        ),
      );

  Widget _pantallaPasos() {
    final titulos = ['Nueva cita', 'Elegir horario', 'Método de pago'];
    final subtitulos = [
      'Paso 1 de 3 — Especialidad',
      _especialidad != null
          ? 'Paso 2 de 3 — ${_especialidad!.nombre}'
          : 'Paso 2 de 3',
      'Paso 3 de 3 — ¿Cómo prefieres pagar?',
    ];

    return PopScope(
      // El botón "atrás" del sistema retrocede un paso en vez de salir.
      canPop: _paso == _Paso.especialidad,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CitasHeader(
          color: AppColors.green,
          titulo: titulos[_pasoStepBar],
          subtitulo: subtitulos[_pasoStepBar],
          stepBar: StepDots(total: 3, actual: _pasoStepBar),
          onBack: _atras,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _paso == _Paso.especialidad
                ? _pasoEspecialidad()
                : _paso == _Paso.horario
                    ? _pasoHorario()
                    : _pasoPago(),
          ),
        ),
      ),
    );
  }

  Widget _pasoEspecialidad() {
    if (_cargandoEspecialidades) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorEspecialidades != null) {
      return _estadoError(_errorEspecialidades!, _cargarEspecialidades);
    }
    if (_especialidades.isEmpty) {
      return const Center(child: Text('No hay especialidades disponibles.'));
    }

    final filtro = _busquedaEspecialidad.trim().toLowerCase();
    final filtradas = filtro.isEmpty
        ? _especialidades
        : _especialidades
            .where((e) => e.nombre.toLowerCase().contains(filtro))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _busquedaEspecialidad = v),
          decoration: const InputDecoration(
            hintText: 'Buscar especialidad...',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.gray400),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtradas.isEmpty
              ? const Center(
                  child: Text('Sin resultados',
                      style: TextStyle(color: AppColors.gray400)),
                )
              : GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: filtradas.map((e) {
                    final sel =
                        _especialidad?.idEspecialidad == e.idEspecialidad;
                    final color = colorParaEspecialidad(e.nombre);
                    return Material(
                      color: sel
                          ? colorFondoParaEspecialidad(e.nombre)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: sel ? color : AppColors.gray100,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _especialidad = e),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(iconoParaEspecialidad(e.nombre),
                                    color: Colors.white, size: 18),
                              ),
                              const Spacer(),
                              Text(e.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                  'S/ ${e.precio.toStringAsFixed(0)} · ${e.medico}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.gray600)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _especialidad == null ? null : _avanzarAHorario,
          child: Text(_especialidad == null
              ? 'Selecciona una especialidad'
              : 'Continuar con ${_especialidad!.nombre}'),
        ),
      ],
    );
  }

  Widget _pasoHorario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorEnvio != null) ...[
          AvisoCard.error(titulo: _errorEnvio!),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _etiqueta('Elige una fecha'),
                const SizedBox(height: 8),
                _calendarioMensual(),
                const SizedBox(height: 18),
                _etiqueta(
                  _fecha == null
                      ? 'Turnos disponibles'
                      : 'Turnos disponibles — ${_formatoDiaMesLocal(_fecha!)}',
                ),
                const SizedBox(height: 8),
                if (_cargandoHorarios)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorHorarios != null)
                  _estadoError(_errorHorarios!, _cargarHorarios)
                else if (_horariosDelDia.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No hay turnos disponibles este día. Prueba otra fecha.',
                      style: TextStyle(fontSize: 13, color: AppColors.gray600),
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
                      final sel = _horario?.idHorario == h.idHorario;
                      return Material(
                        color: sel ? AppColors.green : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: sel ? AppColors.green : AppColors.gray200,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => _horario = h),
                          child: Center(
                            child: Text(
                              h.horaFormateada,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppColors.gray600,
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
          onPressed: _horario == null
              ? null
              : () => setState(() => _paso = _Paso.pago),
          child: Text(_horario == null
              ? 'Elige un turno disponible'
              : 'Continuar con ${_horario!.horaFormateada}'),
        ),
      ],
    );
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _mesesLargos = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const _inicialesDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  DateTime get _primerDiaSeleccionable {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day + 1);
  }

  void _mesAnterior() {
    final anterior = DateTime(_mesVisible.year, _mesVisible.month - 1, 1);
    final limite = DateTime(
        _primerDiaSeleccionable.year, _primerDiaSeleccionable.month, 1);
    if (anterior.isBefore(limite)) return;
    setState(() => _mesVisible = anterior);
  }

  void _mesSiguiente() {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1, 1);
    });
  }

  Widget _calendarioMensual() {
    final hoy = DateTime.now();
    final minSeleccionable = _primerDiaSeleccionable;
    final primerDiaMes = DateTime(_mesVisible.year, _mesVisible.month, 1);
    final diasEnMes = DateTime(_mesVisible.year, _mesVisible.month + 1, 0).day;
    final offsetInicial = primerDiaMes.weekday - 1;

    final puedeRetroceder = _mesVisible.year > minSeleccionable.year ||
        (_mesVisible.year == minSeleccionable.year &&
            _mesVisible.month > minSeleccionable.month);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: puedeRetroceder ? _mesAnterior : null,
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left),
                color: AppColors.gray600,
                disabledColor: AppColors.gray200,
              ),
              Text(
                '${_mesesLargos[_mesVisible.month - 1]} ${_mesVisible.year}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              IconButton(
                onPressed: _mesSiguiente,
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right),
                color: AppColors.gray600,
              ),
            ],
          ),
          Row(
            children: _inicialesDias
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offsetInicial + diasEnMes,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, i) {
              if (i < offsetInicial) return const SizedBox.shrink();
              final dia = i - offsetInicial + 1;
              final fechaCelda =
                  DateTime(_mesVisible.year, _mesVisible.month, dia);
              final esHoy = _mismoDia(fechaCelda, hoy);
              final esSeleccionado =
                  _fecha != null && _mismoDia(fechaCelda, _fecha!);
              final esSeleccionable = !fechaCelda.isBefore(minSeleccionable);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    esSeleccionable ? () => _seleccionarDia(fechaCelda) : null,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        esSeleccionado ? AppColors.green : Colors.transparent,
                    shape: BoxShape.circle,
                    border: esHoy && !esSeleccionado
                        ? Border.all(color: AppColors.green, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    '$dia',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          esSeleccionado ? FontWeight.w700 : FontWeight.w500,
                      color: esSeleccionado
                          ? Colors.white
                          : !esSeleccionable
                              ? AppColors.textoDeshabilitado
                              : AppColors.gray900,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _estadoError(String mensaje, VoidCallback onRetry) {
    return Column(
      children: [
        Text(mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red, fontSize: 13)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }

  Widget _pasoPago() {
    final precio = _especialidad!.precio;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorEnvio != null) ...[
            AvisoCard.error(titulo: _errorEnvio!),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                          '${_especialidad!.nombre} · ${_especialidad!.medico}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatoDiaMesLocal(_fecha!)} · ${_horario!.horaFormateada}',
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
                        color: AppColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _etiqueta('Pagar ahora'),
          const SizedBox(height: 6),
          PayOptionTile(
            icono: Icons.credit_card,
            colorIcono: AppColors.blue,
            colorFondoIcono: AppColors.blueLight,
            titulo: 'Tarjeta débito / crédito',
            subtitulo: 'Visa, Mastercard, Amex',
            seleccionado: _metodoPago == MetodoPago.tarjeta,
            colorSeleccion: AppColors.blue,
            onTap: () => setState(() => _metodoPago = MetodoPago.tarjeta),
          ),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('o pagar presencialmente',
                  style: TextStyle(fontSize: 12, color: AppColors.gray600)),
            ),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 8),
          PayOptionTile(
            icono: Icons.storefront,
            colorIcono: AppColors.amber,
            colorFondoIcono: AppColors.amberLight,
            titulo: 'Pagar en caja del hospital',
            subtitulo: 'Al llegar el día de la cita',
            seleccionado: _metodoPago == MetodoPago.caja,
            colorSeleccion: AppColors.amber,
            onTap: () => setState(() => _metodoPago = MetodoPago.caja),
          ),
          if (_metodoPago == MetodoPago.caja) ...[
            const SizedBox(height: 2),
            const AvisoCard.advertencia(
              titulo: 'Pago pendiente',
              subtitulo:
                  'Debes pagar en caja antes de entrar a tu cita. Llega 15 min antes.',
            ),
          ],
          if (_metodoPago == MetodoPago.tarjeta) ...[
            const SizedBox(height: 14),
            _formularioTarjeta(),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _metodoPago == MetodoPago.caja
                  ? AppColors.green
                  : AppColors.blue,
            ),
            onPressed: _metodoPago == null
                ? null
                : _metodoPago == MetodoPago.caja
                    ? _confirmarCitaYPago
                    : _datosTarjetaCompletos()
                        ? _confirmarCitaYPago
                        : null,
            child: Text(_metodoPago == null
                ? 'Elige cómo pagar'
                : _metodoPago == MetodoPago.caja
                    ? 'Confirmar cita'
                    : 'Pagar S/ ${precio.toStringAsFixed(0)}'),
          ),
        ],
      ),
    );
  }

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
  String _formatoDiaMesLocal(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

  bool _datosTarjetaCompletos() =>
      _numeroTarjetaCtrl.text.replaceAll(' ', '').length >= 12 &&
      _vencimientoCtrl.text.length == 5 &&
      _cvvCtrl.text.length >= 3 &&
      _nombreTarjetaCtrl.text.trim().isNotEmpty;

  Widget _campoLabel(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(texto,
            style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
      );

  Widget _formularioTarjeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.blue, AppColors.blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TARJETA',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 12),
              Text(
                _numeroTarjetaCtrl.text.isEmpty
                    ? '•••• •••• •••• ••••'
                    : _numeroTarjetaCtrl.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _nombreTarjetaCtrl.text.isEmpty
                          ? 'NOMBRE APELLIDO'
                          : _nombreTarjetaCtrl.text.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _vencimientoCtrl.text.isEmpty
                        ? '••/••'
                        : _vencimientoCtrl.text,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _campoLabel('Número de tarjeta'),
        TextField(
          controller: _numeroTarjetaCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [_TarjetaFormatter()],
          autofillHints: const [AutofillHints.creditCardNumber],
          decoration: const InputDecoration(hintText: '4521 0000 0000 0000'),
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
                    inputFormatters: [_VencimientoFormatter()],
                    decoration: const InputDecoration(hintText: 'MM/AA'),
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
          decoration: const InputDecoration(hintText: 'JUAN PEREZ TORRES'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _pantallaConfirmacion() {
    final esCaja = _metodoPago == MetodoPago.caja;
    final especialidad = _especialidad!;
    final comprobante =
        _pagoResultado?.comprobanteReferencia ?? _citaCreada?.idCita ?? '';
    final ultimos4 = _numeroTarjetaCtrl.text.replaceAll(' ', '');
    final tarjetaEnmascarada = ultimos4.length >= 4
        ? '•••• ${ultimos4.substring(ultimos4.length - 4)}'
        : null;

    TextStyle valor([Color? color]) =>
        TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color);

    return ResultadoScreen(
      color: esCaja ? AppColors.amber : AppColors.green,
      icono: Icons.check_circle,
      titulo: '¡Cita confirmada!',
      subtitulo: esCaja
          ? 'Pago pendiente · pagar en caja'
          : 'Pago aprobado · S/ ${especialidad.precio.toStringAsFixed(0)}',
      children: [
        _resumenReal(
          especialidad: especialidad,
          colorCabecera: esCaja ? AppColors.amberLight : AppColors.greenLight,
          colorTextoCabecera: esCaja ? AppColors.amberDark : AppColors.green,
          filas: [
            MapEntry('Médico', Text(especialidad.medico, style: valor())),
            MapEntry('Horario', Text(_horario!.horaFormateada, style: valor())),
            MapEntry(
              'Pago',
              Text(
                esCaja
                    ? '⏳ Pendiente · S/ ${especialidad.precio.toStringAsFixed(0)}'
                    : '✓ Aprobado ${tarjetaEnmascarada ?? ''}',
                style: valor(esCaja ? AppColors.amber : AppColors.green),
              ),
            ),
            MapEntry('Comprobante', Text(comprobante, style: valor())),
          ],
        ),
        const SizedBox(height: 12),
        esCaja
            ? const AvisoCard.advertencia(
                titulo: 'Recuerda pagar en caja',
                subtitulo:
                    'Llega 15 min antes y muestra tu DNI en Caja Central.')
            : const AvisoCard.exito(
                titulo: 'Recibirás un recordatorio 24h antes de tu cita.'),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: _irAInicio, child: const Text('Ir al inicio')),
      ],
    );
  }

  Widget _resumenReal({
    required EspecialidadApi especialidad,
    required List<MapEntry<String, Widget>> filas,
    required Color colorCabecera,
    required Color colorTextoCabecera,
  }) {
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
                  child: Icon(iconoParaEspecialidad(especialidad.nombre),
                      color: Colors.white, size: 18),
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
                      Text(
                          '${_formatoDiaMesLocal(_fecha!)} · ${_horario!.horaFormateada}',
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

  Widget _pantallaRechazo() {
    final ultimos4 = _numeroTarjetaCtrl.text.replaceAll(' ', '');
    return ResultadoScreen(
      color: AppColors.red,
      icono: Icons.close,
      titulo: 'Pago rechazado',
      subtitulo: 'Tu tarjeta no fue aceptada',
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.redLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.red100, width: 2),
            ),
            child: const Icon(Icons.close, color: AppColors.red, size: 32),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Tarjeta rechazada',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        const Text(
          'Fondos insuficientes o datos incorrectos. Puedes intentar con otra tarjeta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.gray600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tarjeta',
                      style: TextStyle(fontSize: 13, color: AppColors.gray600)),
                  Text(
                    '•••• ${ultimos4.length >= 4 ? ultimos4.substring(ultimos4.length - 4) : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estado',
                      style: TextStyle(fontSize: 13, color: AppColors.gray600)),
                  Text('Rechazada',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
          onPressed: () => setState(() => _paso = _Paso.pago),
          child: const Text('Ingresar otra tarjeta'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _irAInicio,
          child: const Text('Cancelar reserva'),
        ),
      ],
    );
  }
}
