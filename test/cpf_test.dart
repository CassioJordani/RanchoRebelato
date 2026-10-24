import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/cpf.dart';

void main() {
  test('aceita CPF válido com e sem pontuação', () {
    expect(isValidCpf('529.982.247-25'), isTrue);
    expect(isValidCpf('52998224725'), isTrue);
    expect(isValidCpf(''), isTrue);
  });

  test('rejeita CPF com dígitos verificadores inválidos ou repetidos', () {
    expect(isValidCpf('529.982.247-24'), isFalse);
    expect(isValidCpf('111.111.111-11'), isFalse);
    expect(isValidCpf('123'), isFalse);
  });

  test('normaliza o CPF mantendo somente números', () {
    expect(normalizeCpf('529.982.247-25'), '52998224725');
  });
}
