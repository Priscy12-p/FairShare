import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please sign in first.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('expenses');
  }

  Stream<List<Expense>> getExpenses() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(<Expense>[]);
    }

    return _collection.where('userId', isEqualTo: user.uid).snapshots().map((
      snapshot,
    ) {
      final expenses = snapshot.docs.map((document) {
        return Expense.fromMap(document.id, document.data());
      }).toList();

      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    });
  }

  Future<void> addExpense(Expense expense) async {
    await _collection.add({...expense.toMap(), 'userId': _userId});
  }

  Future<void> deleteExpense(String expenseId) async {
    final document = _collection.doc(expenseId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data()?['userId'] != _userId) {
      throw Exception('Expense not found or access denied.');
    }

    await document.delete();
  }
}
