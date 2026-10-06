import 'package:flutter/services.dart';

/// Da formato "1234 5678 9012 3456" mientras se escribe.
class TarjetaFormatter extends TextInputFormatter {
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
class VencimientoFormatter extends TextInputFormatter {
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
