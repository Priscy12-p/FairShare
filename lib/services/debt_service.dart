import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/debt.dart';

class DebtService {
  final CollectionReference<Map<String, dynamic>> _debts =
      FirebaseFirestore.instance.collection('debts');

  Future<void> addDebt({
    required String name,
    required double amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to add a person.');
    }

    await _debts.add({
      'name': name,
      'amount': amount,
      'userId': user.uid,
      'createdAt': Timestamp.now(),
    });
  }

  Stream<List<Debt>> getDebts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(<Debt>[]);
    }

    return _debts
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final debts = snapshot.docs.map((document) {
        final data = document.data();
        return Debt(
          id: document.id,
          name: data['name'] as String,
          amount: (data['amount'] as num).toDouble(),
        );
      }).toList();

      debts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return debts;
    });
  }

  Future<void> deleteDebt(String debtId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to update a person.');
    }

    final document = await _debts.doc(debtId).get();
    final data = document.data();

    if (!document.exists || data?['userId'] != user.uid) {
      throw Exception('Person not found or access denied.');
    }

    await _debts.doc(debtId).delete();
  }

  Future<void> restoreDebt(Debt debt) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to restore a person.');
    }

    await _debts.doc(debt.id).set({
      'name': debt.name,
      'amount': debt.amount,
      'userId': user.uid,
      'createdAt': Timestamp.now(),
    });
  }
}
