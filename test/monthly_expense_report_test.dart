import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/expense.dart';
import 'package:flutter_application_1/models/monthly_expense_report.dart';

void main() {
  test('soma despesas e agrupa os valores por categoria em centavos', () {
    final report = MonthlyExpenseReport([
      Expense(
        id: '1',
        description: 'Lanche',
        category: 'Alimentação',
        amountCents: 1250,
        occurredAt: DateTime(2026, 10, 1),
        createdBy: 'admin',
      ),
      Expense(
        id: '2',
        description: 'Material',
        category: 'Artesanato',
        amountCents: 700,
        occurredAt: DateTime(2026, 10, 2),
        createdBy: 'admin',
      ),
      Expense(
        id: '3',
        description: 'Refeição',
        category: 'Alimentação',
        amountCents: 350,
        occurredAt: DateTime(2026, 10, 3),
        createdBy: 'admin',
      ),
    ]);

    expect(report.totalCents, 2300);
    expect(report.totalsByCategory, {'Alimentação': 1600, 'Artesanato': 700});
    expect(report.expenses, hasLength(3));
  });
}
