// CalcTool — AgentTool that evaluates math expressions safely.
//
// Tag: [CALC: expression]
//
// Supports: +, -, *, /, ^ (power), unary minus, parentheses,
//           sqrt(x), abs(x).
//
// Implemented as a hand-rolled recursive descent parser — no eval().
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:math' as math;

import '../agent_tool.dart';
import '../../trust/trust_score.dart';

// ---------------------------------------------------------------------------
// CalcTool
// ---------------------------------------------------------------------------

/// Evaluates a mathematical expression and returns the result.
class CalcTool implements AgentTool {
  @override
  String get tag => 'CALC';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Calculator is not available.';

  @override
  bool get requiresTrust => false;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    try {
      final result = _Parser(argument.trim()).parse();
      final formatted = result == result.toInt()
          ? result.toInt().toString()
          : result.toStringAsPrecision(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return ToolResult.success(
        tag: tag,
        output: formatted,
        characterName: characterName,
      );
    } catch (e) {
      return ToolResult.success(
        tag: tag,
        output: '[CALC_ERROR: invalid expression]',
        characterName: characterName,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _Parser — recursive descent expression parser
// ---------------------------------------------------------------------------

class _Parser {
  final String _src;
  int _pos = 0;

  _Parser(this._src);

  /// Parses and evaluates the full expression, throwing on error.
  double parse() {
    final result = _expr();
    _skipWhitespace();
    if (_pos < _src.length) {
      throw FormatException('Unexpected character at pos $_pos: ${_src[_pos]}');
    }
    return result;
  }

  // expr = term (('+' | '-') term)*
  double _expr() {
    var left = _term();
    while (true) {
      _skipWhitespace();
      if (_pos < _src.length && _src[_pos] == '+') {
        _pos++;
        left += _term();
      } else if (_pos < _src.length && _src[_pos] == '-') {
        _pos++;
        left -= _term();
      } else {
        break;
      }
    }
    return left;
  }

  // term = power (('*' | '/') power)*
  double _term() {
    var left = _power();
    while (true) {
      _skipWhitespace();
      if (_pos < _src.length && _src[_pos] == '*') {
        _pos++;
        left *= _power();
      } else if (_pos < _src.length && _src[_pos] == '/') {
        _pos++;
        final divisor = _power();
        if (divisor == 0) throw Exception('Division by zero');
        left /= divisor;
      } else {
        break;
      }
    }
    return left;
  }

  // power = unary ('^' power)?
  double _power() {
    final base = _unary();
    _skipWhitespace();
    if (_pos < _src.length && _src[_pos] == '^') {
      _pos++;
      final exp = _unary();
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  // unary = '-' unary | primary
  double _unary() {
    _skipWhitespace();
    if (_pos < _src.length && _src[_pos] == '-') {
      _pos++;
      return -_unary();
    }
    return _primary();
  }

  // primary = number | function_call | '(' expr ')'
  double _primary() {
    _skipWhitespace();
    if (_pos >= _src.length) throw FormatException('Unexpected end of input');

    // Parenthesised expression
    if (_src[_pos] == '(') {
      _pos++;
      final val = _expr();
      _skipWhitespace();
      if (_pos >= _src.length || _src[_pos] != ')') {
        throw FormatException('Missing closing parenthesis');
      }
      _pos++;
      return val;
    }

    // Named functions (sqrt, abs)
    if (_isLetter(_src[_pos])) {
      final fn = _readIdentifier();
      _skipWhitespace();
      if (_pos >= _src.length || _src[_pos] != '(') {
        throw FormatException('Expected "(" after function "$fn"');
      }
      _pos++;
      final arg = _expr();
      _skipWhitespace();
      if (_pos >= _src.length || _src[_pos] != ')') {
        throw FormatException('Missing ")" in function call "$fn"');
      }
      _pos++;
      switch (fn.toLowerCase()) {
        case 'sqrt':
          if (arg < 0) throw Exception('sqrt of negative');
          return math.sqrt(arg);
        case 'abs':
          return arg.abs();
        default:
          throw FormatException('Unknown function: $fn');
      }
    }

    return _number();
  }

  double _number() {
    _skipWhitespace();
    final start = _pos;
    while (_pos < _src.length &&
        (RegExp(r'[0-9.]').hasMatch(_src[_pos]))) {
      _pos++;
    }
    if (_pos == start) {
      throw FormatException('Expected number at pos $_pos');
    }
    return double.parse(_src.substring(start, _pos));
  }

  String _readIdentifier() {
    final start = _pos;
    while (_pos < _src.length && _isLetter(_src[_pos])) {
      _pos++;
    }
    return _src.substring(start, _pos);
  }

  void _skipWhitespace() {
    while (_pos < _src.length && _src[_pos] == ' ') {
      _pos++;
    }
  }

  bool _isLetter(String ch) => RegExp(r'[a-zA-Z]').hasMatch(ch);
}
