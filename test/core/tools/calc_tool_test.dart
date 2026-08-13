import 'package:test/test.dart';
import 'package:deep_think_er/core/tools/calc/calc_tool.dart';

void main() {
  group('CalcTool', () {
    final calc = CalcTool();

    Future<String> eval(String expr) async {
      final result = await calc.execute(expr, 'WATSON');
      return result.output;
    }

    group('basic arithmetic', () {
      test('addition', () async => expect(await eval('2 + 3'), '5'));
      test('subtraction', () async => expect(await eval('10 - 4'), '6'));
      test('multiplication', () async => expect(await eval('3 * 7'), '21'));
      test('division', () async => expect(await eval('15 / 3'), '5'));
      test('integer result strips .0', () async => expect(await eval('4 / 2'), '2'));
    });

    group('operator precedence', () {
      test('* before +', () async => expect(await eval('2 + 3 * 4'), '14'));
      test('() overrides precedence', () async => expect(await eval('(2 + 3) * 4'), '20'));
      test('nested parentheses', () async => expect(await eval('(1 + (2 * 3))'), '7'));
    });

    group('power operator', () {
      test('2^10', () async => expect(await eval('2^10'), '1024'));
      test('3^3', () async => expect(await eval('3^3'), '27'));
    });

    group('unary minus', () {
      test('-5 + 3', () async => expect(await eval('-5 + 3'), '-2'));
      test('3 * -2', () async => expect(await eval('3 * -2'), '-6'));
    });

    group('functions', () {
      test('sqrt(9)', () async => expect(await eval('sqrt(9)'), '3'));
      test('sqrt(2) is approximately 1.41', () async {
        final r = await eval('sqrt(2)');
        expect(double.parse(r), closeTo(1.4142, 0.0001));
      });
      test('abs(-7)', () async => expect(await eval('abs(-7)'), '7'));
      test('abs(3)', () async => expect(await eval('abs(3)'), '3'));
    });

    group('error handling', () {
      test('division by zero returns CALC_ERROR', () async {
        expect(await eval('1 / 0'), contains('CALC_ERROR'));
      });

      test('sqrt of negative returns CALC_ERROR', () async {
        expect(await eval('sqrt(-4)'), contains('CALC_ERROR'));
      });

      test('unknown function returns CALC_ERROR', () async {
        expect(await eval('log(10)'), contains('CALC_ERROR'));
      });

      test('empty expression returns CALC_ERROR', () async {
        expect(await eval(''), contains('CALC_ERROR'));
      });

      test('non-numeric input returns CALC_ERROR', () async {
        expect(await eval('hello world'), contains('CALC_ERROR'));
      });

      test('mismatched parentheses returns CALC_ERROR', () async {
        expect(await eval('(2 + 3'), contains('CALC_ERROR'));
      });
    });

    group('tool metadata', () {
      test('tag is CALC', () => expect(calc.tag, 'CALC'));
      test('enabled is true', () => expect(calc.enabled, isTrue));
      test('requiresTrust is false', () => expect(calc.requiresTrust, isFalse));
    });
  });
}
