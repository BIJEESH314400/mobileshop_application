import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/employee.dart';

/// The only place that talks to the `employees` Firestore collection
/// and creates employee Firebase Auth logins — same "one repository per
/// collection" pattern as ProductRepository/SaleRepository.
///
/// Creating an employee's login is trickier than creating a product:
/// Firebase Auth's `createUserWithEmailAndPassword` immediately signs
/// the *caller* in as the newly created user — which would kick the
/// shop owner out of their own session the moment they add staff. To
/// avoid that, the new account is created on a short-lived *second*
/// Firebase app (a separate, throwaway connection to the same Firebase
/// project) instead of the app's main one, so the owner's own sign-in
/// never moves. The temporary app is deleted right after, leaving
/// nothing behind but the new employee's account.
class EmployeeRepository {
  final FirebaseFirestore _db;

  EmployeeRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _employees => _db.collection('employees');
  CollectionReference<Map<String, dynamic>> get _usernames => _db.collection('usernames');

  /// A live list of this shop's employees, newest first.
  Stream<List<Employee>> watchEmployees({required String shopId}) {
    return _employees.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      final employees = snapshot.docs.map((doc) => Employee.fromMap(doc.id, doc.data())).toList();
      employees.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return employees;
    });
  }

  /// Creates a real login for a new employee: a Firebase Auth account
  /// (same synthetic-email pattern the owner's own login uses), an
  /// `employees/<uid>` document, and a `usernames/<username>` entry so
  /// Forgot Password works for employees exactly like it does for the
  /// owner. Throws a [FirebaseAuthException] if the username is already
  /// taken (Firebase Auth rejects the duplicate email under the hood).
  Future<void> addEmployee({
    required String name,
    required String username,
    required String password,
    required String shopId,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final email = '$cleanUsername@4bmobiles.app';

    // A throwaway second connection to the same Firebase project, used
    // only to create this one account — see class doc above.
    final tempApp = await Firebase.initializeApp(
      name: 'employeeCreation_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await tempAuth.signOut();

      final employee = Employee(id: uid, name: name.trim(), username: cleanUsername, shopId: shopId);

      // All three documents are written together so a half-created
      // employee (auth account but no profile, or a profile with no
      // chat thread yet) never happens. The conversation doc is
      // created right away — see the Conversation model doc comment —
      // so the chat thread exists the instant the employee does, even
      // before either side sends a first message.
      final batch = _db.batch();
      batch.set(_employees.doc(uid), employee.toMap());
      batch.set(_usernames.doc(cleanUsername), {'email': email});
      batch.set(_db.collection('conversations').doc(uid), {
        'employeeName': employee.name,
        'employeeUsername': employee.username,
        'shopId': shopId,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderRole': null,
        'unreadForOwner': false,
        'unreadForEmployee': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } finally {
      // Always clean up the temporary app, even if account creation
      // or the Firestore write above failed partway through.
      await tempApp.delete();
    }
  }
}
