import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/enrollment.dart';
import '../models/expense.dart';
import '../models/monthly_expense_report.dart';
import '../models/organization_member.dart';
import '../models/student.dart';
import '../models/user_role.dart';
import '../models/workshop_class.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const organizationId = 'rancho-rebelato';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _organization => _firestore
      .collection('organizations')
      .doc(organizationId)
      .collection('members');

  DocumentReference<Map<String, dynamic>> get _organizationDocument =>
      _firestore.collection('organizations').doc(organizationId);

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('É necessário estar autenticado para acessar os dados.');
    }
    return user.uid;
  }

  Stream<UserRole?> watchCurrentUserRole() {
    return _organization.doc(_currentUid).snapshots().map((document) {
      if (!document.exists) return null;
      return UserRole.fromValue(document.data()?['role']);
    });
  }

  Future<void> ensureViewerProfile(User user) async {
    final member = _organization.doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(member);
      if (snapshot.exists) return;
      final email = user.email ?? '';
      final displayName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (email.contains('@') ? email.split('@').first : 'Usuário');
      transaction.set(member, {
        'role': UserRole.viewer.name,
        'displayName': displayName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<OrganizationMember>> watchMembers() {
    return _organization.snapshots().map((snapshot) {
      final members = snapshot.docs
          .map(OrganizationMember.fromDocument)
          .toList();
      members.sort((a, b) {
        final aName = a.displayName.isEmpty ? a.email : a.displayName;
        final bName = b.displayName.isEmpty ? b.email : b.displayName;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
      return members;
    });
  }

  Future<void> updateMemberRole(String uid, UserRole role) async {
    await _organization.doc(uid).update({'role': role.name});
  }

  Stream<String?> watchMemberName(String uid) {
    return _organization.doc(uid).snapshots().map((document) {
      final value = document.data()?['displayName'];
      return value is String && value.trim().isNotEmpty ? value : null;
    });
  }

  Stream<List<WorkshopClass>> watchClasses({required UserRole role}) {
    Query<Map<String, dynamic>> query = _organizationDocument.collection(
      'classes',
    );
    if (role == UserRole.instructor) {
      query = query.where('instructorUid', isEqualTo: _currentUid);
    }
    return query
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(WorkshopClass.fromDocument).toList(),
        );
  }

  Future<String> createClass(WorkshopClass workshopClass) async {
    final document = _organizationDocument.collection('classes').doc();
    await document.set({
      ...workshopClass.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Future<void> updateClass(WorkshopClass workshopClass) async {
    await _organizationDocument
        .collection('classes')
        .doc(workshopClass.id)
        .update({
          ...workshopClass.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteClass(String classId) async {
    final classDocument = _organizationDocument
        .collection('classes')
        .doc(classId);
    final enrollmentSnapshot = await classDocument
        .collection('enrollments')
        .get();
    for (var start = 0; start < enrollmentSnapshot.docs.length; start += 400) {
      final batch = _firestore.batch();
      final end = (start + 400).clamp(0, enrollmentSnapshot.docs.length);
      for (final enrollment in enrollmentSnapshot.docs.sublist(start, end)) {
        batch.delete(enrollment.reference);
      }
      await batch.commit();
    }
    await classDocument.delete();
  }

  Stream<List<Student>> watchStudents() {
    return _organizationDocument
        .collection('students')
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Student.fromDocument).toList());
  }

  Future<String> createStudent(Student student) async {
    final document = _organizationDocument.collection('students').doc();
    await document.set({
      ...student.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Future<void> updateStudent(Student student) async {
    await _organizationDocument.collection('students').doc(student.id).update({
      ...student.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStudent(String studentId) async {
    await _organizationDocument.collection('students').doc(studentId).delete();
  }

  Stream<List<Enrollment>> watchEnrollments(String classId) {
    return _organizationDocument
        .collection('classes')
        .doc(classId)
        .collection('enrollments')
        .orderBy('enrolledAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Enrollment.fromDocument).toList());
  }

  Future<String> createEnrollment({
    required String classId,
    required Enrollment enrollment,
  }) async {
    final document = _organizationDocument
        .collection('classes')
        .doc(classId)
        .collection('enrollments')
        .doc();
    await document.set(enrollment.toMap());
    return document.id;
  }

  Future<void> updateEnrollment({
    required String classId,
    required Enrollment enrollment,
  }) async {
    await _organizationDocument
        .collection('classes')
        .doc(classId)
        .collection('enrollments')
        .doc(enrollment.id)
        .update(enrollment.toMap());
  }

  Stream<MonthlyExpenseReport> watchMonthlyExpenses(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _organizationDocument
        .collection('expenses')
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('occurredAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('occurredAt')
        .snapshots()
        .map(
          (snapshot) =>
              MonthlyExpenseReport(snapshot.docs.map(Expense.fromDocument)),
        );
  }

  Future<String> createExpense({
    required String description,
    required String category,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    final document = _organizationDocument.collection('expenses').doc();
    await document.set({
      'description': description,
      'category': category,
      'amountCents': amountCents,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'createdBy': _currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Future<void> updateExpense({
    required String expenseId,
    required String description,
    required String category,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    await _organizationDocument.collection('expenses').doc(expenseId).update({
      'description': description,
      'category': category,
      'amountCents': amountCents,
      'occurredAt': Timestamp.fromDate(occurredAt),
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _organizationDocument.collection('expenses').doc(expenseId).delete();
  }
}
