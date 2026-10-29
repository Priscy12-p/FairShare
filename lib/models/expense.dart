import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final String paidBy;
  final List<String> participants;
  final DateTime date;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.participants,
    required this.date,
  });

  // Everyone included in the expense shares it equally.
  double get sharePerPerson {
    if (participants.isEmpty) return 0;
    return amount / participants.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'participants': participants,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final savedDate = map['date'];

    return Expense(
      id: id,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paidBy'] as String,
      participants: List<String>.from(map['participants'] ?? []),
      date: savedDate is Timestamp ? savedDate.toDate() : DateTime.now(),
    );
  }
}
