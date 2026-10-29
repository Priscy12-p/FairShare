# FairShare

A mobile app for splitting shared expenses with friends and keeping track of who owes whom. Built with **Flutter**, **Firebase Authentication** and **Cloud Firestore**.

> Elective project: Mobile Development (WeThinkCode_), Semester 3, 2026.
> Demo video: **[ADD YOUR UNLISTED YOUTUBE LINK HERE]**

---

## Screenshots

<!-- Add your screenshots to a /screenshots folder, then update these paths. -->

| Login | Home | Expenses |
|-------|------|----------|
| ![Login](screenshots/login.png) | ![Home](screenshots/home.png) | ![Expenses](screenshots/expenses.png) |

| Add expense (split) | People and balances | Profile |
|---------------------|---------------------|---------|
| ![Add expense](screenshots/add_expense.png) | ![People](screenshots/people.png) | ![Profile](screenshots/profile.png) |

---

## What it does

- **Sign up and log in** with Firebase Authentication. Each user only sees their own data.
- **Add expenses and split them equally** between any people you name. You choose who paid and who shares the cost.
- **See balances per person.** The app works out who owes you and who you owe, based on all your shared expenses.
- **Settle up** with one tap. A payment is recorded and the balance goes back to zero, with an **Undo** option.
- **Track extra debts** by adding people who owe you money outside of shared expenses, and mark them as paid (also with Undo).
- **Live updates.** The screens update straight away when the data in Firestore changes.
- **Swipe to delete** an expense.

---

## How the splitting works

Every expense stores:

| Field | Meaning |
|-------|---------|
| `description` | What it was for |
| `amount` | Total cost |
| `paidBy` | Who paid (`You` or a person's name) |
| `participants` | Everyone who shares the cost |
| `isSettlement` | `true` if it is a "paid back" record from Settle up |

The cost is split **equally** between the participants. The person who paid is owed everyone else's share.

**Example**

1. *Dinner*, R300, you paid, split between You, Sam and Thandi. Each share is R100, so Sam owes you R100 and Thandi owes you R100.
2. *Taxi*, R90, Sam paid, split between You and Thandi. Each share is R45, so you owe Sam R45.
3. Net result for Sam: R100 owed to you, minus R45 you owe, so **Sam owes you R55**.

The calculation lives in `computeBalances` in `lib/models/expense.dart`. A positive number means they owe you, and a negative number means you owe them.

**Settle up** does not edit old expenses. It adds a new record (`isSettlement: true`) that cancels out the balance, which is why Undo is easy: it just deletes that one record. Settlements are not counted as spending.

---

## Tech stack

- Flutter and Dart (Material 3)
- Firebase Authentication (email and password)
- Cloud Firestore (real-time streams)

---

## Project structure

```
lib/
  main.dart                  App entry, AuthGate, dashboard and all screens
  login_page.dart            Login / sign-up screen
  firebase_options.dart      Generated Firebase config
  models/
    expense.dart             Expense model and balance calculation
    debt.dart                Debt model
  services/
    expense_service.dart     Firestore reads and writes for expenses
    debt_service.dart        Firestore reads and writes for debts
```

**Key ideas**

- `AuthGate` listens to `authStateChanges()` and shows the login page or the dashboard.
- `AppShell` subscribes to the expense and debt streams in `initState` and cancels them in `dispose`, so there are no leaks.
- Services talk to Firestore. The screens never touch Firestore directly.
- Totals and balances are calculated from the lists, not stored, so they can never get out of sync.

---

## Data model (Firestore)

Each user's expenses are stored under their own user id:

```
users/{uid}/expenses/{expenseId}
```

Suggested security rules, so users can only read and write their own data:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

If your debts are stored somewhere else, adjust the rules to match.

---

## Run it yourself

**Requirements:** Flutter SDK, a Firebase project with Authentication (email/password) and Firestore enabled.

```bash
git clone [YOUR REPO URL]
cd fairshare
flutter pub get
```

Connect your own Firebase project (this generates `lib/firebase_options.dart`):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then run it:

```bash
flutter run
```

To check the code:

```bash
flutter analyze
```

---

## Known limitations

I would rather be upfront about these than hide them:

- **Equal splits only.** There are no custom amounts or percentages per person.
- **Other people are just names.** Friends do not have their own accounts, so only the person using the app sees the data.
- **Names are matched by text.** "Sam" and "Sam " are cleaned up, but two different people with the same name would be treated as one.
- **Single currency (Rand).**
- **No automated tests yet.**

## What I would build next

- Shared groups, so friends can join with an invite and see the same expenses live on their own phones.
- Custom splits (by amount, percentage or item).
- Expense categories and a spending summary.
- Unit tests for `computeBalances`.

