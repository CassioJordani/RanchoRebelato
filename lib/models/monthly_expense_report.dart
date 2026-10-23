import 'expense.dart';

class MonthlyExpenseReport {
  factory MonthlyExpenseReport(Iterable<Expense> expenses) {
    final entries = List<Expense>.of(expenses);
    return MonthlyExpenseReport._(entries);
  }

  MonthlyExpenseReport._(List<Expense> entries)
    : expenses = List.unmodifiable(entries),
      totalCents = entries.fold(
        0,
        (total, expense) => total + expense.amountCents,
      ),
      totalsByCategory = _totalsByCategory(entries);

  final List<Expense> expenses;
  final int totalCents;
  final Map<String, int> totalsByCategory;

  static Map<String, int> _totalsByCategory(Iterable<Expense> expenses) {
    final totals = <String, int>{};
    for (final expense in expenses) {
      totals.update(
        expense.category,
        (total) => total + expense.amountCents,
        ifAbsent: () => expense.amountCents,
      );
    }
    return Map.unmodifiable(totals);
  }
}
