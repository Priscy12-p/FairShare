import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'models/expense.dart';
import 'models/debt.dart';
import 'services/expense_service.dart';
import 'services/debt_service.dart';

const Color kPurple = Color(0xFF7357D9);
const Color kBackground = Color(0xFFF7F6FC);

// The value saved in Expense.paidBy when the signed-in user paid.
const String kPaidByYou = 'You';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const FairShareApp());
}

String money(double value) => 'R ${value.toStringAsFixed(2)}';

class FairShareApp extends StatelessWidget {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Shows login when signed out and the dashboard when signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return AppShell(key: ValueKey(snapshot.data!.uid));
        }

        return LoginPage();
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late String _userName;

  // Connect to the Firestore services.
  final ExpenseService _expenseService = ExpenseService();
  final DebtService _debtService = DebtService();

  // Firestore updates these lists whenever data changes.
  List<Expense> _expenses = [];
  List<Debt> _debts = [];

  // These subscriptions belong to the dashboard.
  late final StreamSubscription<List<Expense>> _expenseSubscription;
  late final StreamSubscription<List<Debt>> _debtSubscription;

  @override
  void initState() {
    super.initState();

    // Get the signed-in user's name.
    final user = FirebaseAuth.instance.currentUser;
    final emailName = (user?.email ?? '').split('@').first;
    final displayName = user?.displayName?.trim() ?? '';

    _userName = displayName.isNotEmpty
        ? displayName
        : (emailName.isNotEmpty ? emailName : 'Friend');

    // Listen for this user's expenses in Firestore.
    _expenseSubscription = _expenseService.getExpenses().listen(
      (expenses) {
        if (!mounted) return;

        setState(() {
          _expenses = expenses;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load expenses: $error')),
        );
      },
    );

    // Listen for this user's debts in Firestore.
    _debtSubscription = _debtService.getDebts().listen(
      (debts) {
        if (!mounted) return;

        setState(() {
          _debts = debts;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load people who owe you: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    // Stop the Firestore listeners when the dashboard closes.
    unawaited(_expenseSubscription.cancel());
    unawaited(_debtSubscription.cancel());
    super.dispose();
  }

  // ----- Totals -----

  double get _owedToYou => _debts.fold(0.0, (sum, debt) => sum + debt.amount);

  double get _youOwe => _expenses
      .where((expense) => expense.paidBy != kPaidByYou)
      .fold(0.0, (sum, expense) => sum + expense.amount);

  double get _expensesTotal =>
      _expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  // ----- Actions -----

  Future<void> _addExpense() async {
    final result = await showEntryDialog(
      context,
      title: 'Add expense',
      nameLabel: 'What was it for?',
      amountLabel: 'Amount (R)',
      showPaidSwitch: true,
    );

    if (result == null) return;

    final expense = Expense(
      id: '',
      description: result.name,
      amount: result.amount,
      paidBy: result.paidByYou ? kPaidByYou : 'Someone else',
      participants: [_userName],
      date: DateTime.now(),
    );

    try {
      // Save to Firestore. The listener updates the screen.
      await _expenseService.addExpense(expense);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved successfully!')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save expense: $error')));
    }
  }

  Future<void> _addDebt() async {
    final result = await showEntryDialog(
      context,
      title: 'Add person',
      nameLabel: 'Their name',
      amountLabel: 'Amount they owe you (R)',
    );

    if (result == null || !mounted) return;

    try {
      // Save the debt to Firestore. The listener updates the screen.
      await _debtService.addDebt(name: result.name, amount: result.amount);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person saved successfully!')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save person: $error')));
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      // Delete from Firestore, not just from the screen.
      await _expenseService.deleteExpense(expense.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${expense.description} deleted')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete expense: $error')),
      );
    }
  }

  Future<void> _markPaid(Debt debt) async {
    try {
      // Remove the debt from Firestore. The listener updates the screen.
      await _debtService.deleteDebt(debt.id);

      if (!mounted) return;

      _showUndo('${debt.name} paid ${money(debt.amount)}', () {
        _restoreDebt(debt);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update payment: $error')),
      );
    }
  }

  Future<void> _restoreDebt(Debt debt) async {
    try {
      // Undo restores the same Firestore document.
      await _debtService.restoreDebt(debt);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment action undone.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not undo payment: $error')));
    }
  }

  void _showUndo(String message, VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Your name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  // ----- Dashboard UI -----

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        userName: _userName,
        owedToYou: _owedToYou,
        youOwe: _youOwe,
        expensesTotal: _expensesTotal,
        expenses: _expenses,
        debts: _debts,
        onPaid: _markPaid,
        onSeeExpenses: () => setState(() => _index = 1),
        onSeePeople: () => setState(() => _index = 2),
      ),
      ExpensesPage(
        expenses: _expenses,
        total: _expensesTotal,
        onDelete: _deleteExpense,
      ),
      PeoplePage(debts: _debts, total: _owedToYou, onPaid: _markPaid),
      ProfilePage(
        userName: _userName,
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        onSignOut: () async {
          await FirebaseAuth.instance.signOut();
        },
        owedToYou: _owedToYou,
        youOwe: _youOwe,
        expenseCount: _expenses.length,
        peopleCount: _debts.length,
        onEditName: _editName,
      ),
    ];

    const titles = ['FairShare', 'Expenses', 'People who owe you', 'Profile'];

    Widget? fab;

    if (_index == 1) {
      fab = FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      );
    } else if (_index == 2) {
      fab = FloatingActionButton.extended(
        onPressed: _addDebt,
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add person'),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        title: Text(
          titles[_index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home page
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  final String userName;
  final double owedToYou;
  final double youOwe;
  final double expensesTotal;
  final List<Expense> expenses;
  final List<Debt> debts;
  final void Function(Debt) onPaid;
  final VoidCallback onSeeExpenses;
  final VoidCallback onSeePeople;

  const HomePage({
    super.key,
    required this.userName,
    required this.owedToYou,
    required this.youOwe,
    required this.expensesTotal,
    required this.expenses,
    required this.debts,
    required this.onPaid,
    required this.onSeeExpenses,
    required this.onSeePeople,
  });

  @override
  Widget build(BuildContext context) {
    final netBalance = owedToYou - youOwe;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi $userName 👋',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your money, shared fairly.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPurple,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your net balance',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  money(netBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Money owed to you minus what you owe',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BalanceCard(
                  title: 'You are owed',
                  amount: owedToYou,
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                  onTap: onSeePeople,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BalanceCard(
                  title: 'You owe',
                  amount: youOwe,
                  icon: Icons.arrow_upward,
                  color: Colors.orange,
                  onTap: onSeeExpenses,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onSeeExpenses,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEDE8FF),
                    child: Icon(Icons.receipt_long, color: kPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total expenses',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          '${money(expensesTotal)} · '
                          '${expenses.length} recorded',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Who owes you',
            actionLabel: 'View all',
            onAction: onSeePeople,
          ),
          if (debts.isEmpty)
            const EmptyNote('Nobody owes you anything right now.')
          else
            ...debts
                .take(3)
                .map(
                  (debt) => DebtTile(debt: debt, onPaid: () => onPaid(debt)),
                ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Recent expenses',
            actionLabel: 'View all',
            onAction: onSeeExpenses,
          ),
          if (expenses.isEmpty)
            const EmptyNote('No expenses yet.')
          else
            ...expenses.take(3).map((expense) => ExpenseTile(expense: expense)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expenses page
// ---------------------------------------------------------------------------

class ExpensesPage extends StatelessWidget {
  final List<Expense> expenses;
  final double total;
  final Future<void> Function(Expense) onDelete;

  const ExpensesPage({
    super.key,
    required this.expenses,
    required this.total,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        TotalBanner(label: 'Total expenses', amount: total),
        const SizedBox(height: 16),
        if (expenses.isEmpty)
          const EmptyNote('No expenses yet. Tap "Add expense" to start.')
        else ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Swipe an expense left or right to delete it.',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
          for (final expense in expenses)
            Dismissible(
              // Use the Firestore document id as the stable key.
              key: ValueKey(expense.id),
              background: const DeleteBackground(),
              onDismissed: (_) {
                onDelete(expense);
              },
              child: ExpenseTile(expense: expense),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// People page
// ---------------------------------------------------------------------------

class PeoplePage extends StatelessWidget {
  final List<Debt> debts;
  final double total;
  final void Function(Debt) onPaid;

  const PeoplePage({
    super.key,
    required this.debts,
    required this.total,
    required this.onPaid,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        TotalBanner(label: 'Total owed to you', amount: total),
        const SizedBox(height: 16),
        if (debts.isEmpty)
          const EmptyNote(
            'Nobody owes you anything. '
            'Tap "Add person" to record an amount.',
          )
        else
          for (final debt in debts)
            DebtTile(debt: debt, onPaid: () => onPaid(debt)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile page
// ---------------------------------------------------------------------------

class ProfilePage extends StatelessWidget {
  final String userName;
  final String email;
  final VoidCallback onSignOut;
  final double owedToYou;
  final double youOwe;
  final int expenseCount;
  final int peopleCount;
  final VoidCallback onEditName;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.email,
    required this.onSignOut,
    required this.owedToYou,
    required this.youOwe,
    required this.expenseCount,
    required this.peopleCount,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final initial = userName.isEmpty ? '?' : userName[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: kPurple,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            userName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        if (email.isNotEmpty)
          Center(
            child: Text(email, style: const TextStyle(color: Colors.black54)),
          ),
        Center(
          child: TextButton.icon(
            onPressed: onEditName,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit name'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BalanceCard(
                title: 'You are owed',
                amount: owedToYou,
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BalanceCard(
                title: 'You owe',
                amount: youOwe,
                icon: Icons.arrow_upward,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long, color: kPurple),
                title: const Text('Expenses recorded'),
                trailing: Text(
                  '$expenseCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.people, color: kPurple),
                title: const Text('People who owe you'),
                trailing: Text(
                  '$peopleCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add expense / person dialog
// ---------------------------------------------------------------------------

class EntryResult {
  final String name;
  final double amount;
  final bool paidByYou;

  const EntryResult(this.name, this.amount, this.paidByYou);
}

Future<EntryResult?> showEntryDialog(
  BuildContext context, {
  required String title,
  required String nameLabel,
  required String amountLabel,
  bool showPaidSwitch = false,
}) {
  return showDialog<EntryResult>(
    context: context,
    builder: (_) => EntryDialog(
      title: title,
      nameLabel: nameLabel,
      amountLabel: amountLabel,
      showPaidSwitch: showPaidSwitch,
    ),
  );
}

class EntryDialog extends StatefulWidget {
  final String title;
  final String nameLabel;
  final String amountLabel;
  final bool showPaidSwitch;

  const EntryDialog({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.amountLabel,
    required this.showPaidSwitch,
  });

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _paidByYou = true;
  String? _error;

  @override
  void dispose() {
    // These controllers belong to this dialog.
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter an amount above 0.');
      return;
    }

    Navigator.pop(context, EntryResult(name, amount, _paidByYou));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: widget.nameLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.amountLabel,
                prefixText: 'R ',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.showPaidSwitch)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I paid for this'),
                value: _paidByYou,
                onChanged: (value) {
                  setState(() => _paidByYou = value);
                },
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const SectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: const TextStyle(color: Colors.black45)),
    );
  }
}

class TotalBanner extends StatelessWidget {
  final String label;
  final double amount;

  const TotalBanner({super.key, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            money(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class DeleteBackground extends StatelessWidget {
  const DeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}

class BalanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              money(amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;

  const ExpenseTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEDE8FF),
          child: Icon(Icons.receipt_long_outlined, color: kPurple),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          expense.paidBy == kPaidByYou ? 'Paid by you' : 'Paid by someone else',
        ),
        trailing: Text(
          money(expense.amount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class DebtTile extends StatelessWidget {
  final Debt debt;
  final VoidCallback onPaid;

  const DebtTile({super.key, required this.debt, required this.onPaid});

  @override
  Widget build(BuildContext context) {
    final initial = debt.name.isEmpty ? '?' : debt.name[0].toUpperCase();

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEDE8FF),
          child: Text(
            initial,
            style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          debt.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          money(debt.amount),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: FilledButton.tonalIcon(
          onPressed: onPaid,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Paid'),
        ),
      ),
    );
  }
}
