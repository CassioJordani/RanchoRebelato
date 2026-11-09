import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendance_record.dart';
import '../models/attendance_lesson.dart';
import '../models/cpf.dart';
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

  CollectionReference<Map<String, dynamic>> get _students =>
      _organizationDocument.collection('students');

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

  Stream<List<OrganizationMember>> watchInstructors() {
    return watchMembers().map(
      (members) => members
          .where((member) => member.role == UserRole.instructor)
          .toList(),
    );
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
    await _deleteDocuments(
      enrollmentSnapshot.docs.map((document) => document.reference).toList(),
    );

    final attendanceSessions = await classDocument
        .collection('attendance')
        .get();
    for (final session in attendanceSessions.docs) {
      final attendanceRecords = await session.reference
          .collection('students')
          .get();
      await _deleteDocuments(
        attendanceRecords.docs.map((document) => document.reference).toList(),
      );
    }
    await _deleteDocuments(
      attendanceSessions.docs.map((document) => document.reference).toList(),
    );
    await classDocument.delete();
  }

  Future<void> _deleteDocuments(
    List<DocumentReference<Map<String, dynamic>>> documents,
  ) async {
    for (var start = 0; start < documents.length; start += 400) {
      final batch = _firestore.batch();
      final end = (start + 400).clamp(0, documents.length);
      for (final document in documents.sublist(start, end)) {
        batch.delete(document);
      }
      await batch.commit();
    }
  }

  Stream<List<Student>> watchStudents() {
    return _students
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Student.fromDocument).toList());
  }

  Future<String> createStudent(Student student) async {
    _validateStudentCpfs(student);
    await _ensureStudentCpfIsUnique(student);
    final document = _students.doc();
    await document.set({
      ...student.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Future<void> updateStudent(Student student) async {
    _validateStudentCpfs(student);
    await _ensureStudentCpfIsUnique(student);
    await _students.doc(student.id).update({
      ...student.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStudent(String studentId) async {
    await _students.doc(studentId).delete();
  }

  void _validateStudentCpfs(Student student) {
    if (!isValidCpf(student.cpf)) {
      throw StateError('Informe um CPF válido para o aluno.');
    }
    if (!isValidCpf(student.guardianCpf)) {
      throw StateError('Informe um CPF válido para o responsável.');
    }
  }

  Future<void> _ensureStudentCpfIsUnique(Student student) async {
    final cpf = normalizeCpf(student.cpf);
    if (cpf.isEmpty) return;

    final students = await _students.get();
    final duplicate = students.docs.any((document) {
      if (document.id == student.id) return false;
      final existingCpf = document.data()['cpf'];
      return existingCpf is String && normalizeCpf(existingCpf) == cpf;
    });
    if (duplicate) {
      throw StateError('Já existe um aluno cadastrado com este CPF.');
    }
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
    final classDocument = _organizationDocument
        .collection('classes')
        .doc(classId);
    final enrollments = classDocument.collection('enrollments');
    final document = enrollments.doc(enrollment.studentId);
    await _ensureStudentIsNotEnrolled(enrollments, enrollment.studentId);
    final initialClassSnapshot = await classDocument.get();
    if (!initialClassSnapshot.exists) {
      throw StateError('A turma não existe mais.');
    }
    final initialActiveCount = await _activeEnrollmentCount(
      enrollments,
      initialClassSnapshot.data()!,
    );

    await _firestore.runTransaction((transaction) async {
      final classSnapshot = await transaction.get(classDocument);
      final enrollmentSnapshot = await transaction.get(document);
      if (!classSnapshot.exists) {
        throw StateError('A turma não existe mais.');
      }
      if (enrollmentSnapshot.exists) {
        throw StateError('Este aluno já está matriculado nesta turma.');
      }

      final classData = classSnapshot.data()!;
      final capacity = classData['capacity'];
      if (capacity is! int || capacity < 1) {
        throw StateError('O limite de vagas da turma é inválido.');
      }
      final storedCount = classData['activeEnrollmentCount'];
      final activeCount = storedCount is int && storedCount >= 0
          ? storedCount
          : initialActiveCount;
      if (enrollment.status == 'active' && activeCount >= capacity) {
        throw StateError('Não há vagas disponíveis nesta turma.');
      }

      transaction.set(document, enrollment.toMap());
      transaction.update(classDocument, {
        'activeEnrollmentCount':
            activeCount + (enrollment.status == 'active' ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return document.id;
  }

  Future<void> updateEnrollment({
    required String classId,
    required Enrollment enrollment,
  }) async {
    final classDocument = _organizationDocument
        .collection('classes')
        .doc(classId);
    final enrollments = classDocument.collection('enrollments');
    final document = enrollments.doc(enrollment.id);
    final canonicalDocument = enrollments.doc(enrollment.studentId);
    await _ensureStudentIsNotEnrolled(
      enrollments,
      enrollment.studentId,
      excludingEnrollmentId: enrollment.id,
    );
    final initialClassSnapshot = await classDocument.get();
    if (!initialClassSnapshot.exists) {
      throw StateError('A turma não existe mais.');
    }
    final initialActiveCount = await _activeEnrollmentCount(
      enrollments,
      initialClassSnapshot.data()!,
    );

    await _firestore.runTransaction((transaction) async {
      final classSnapshot = await transaction.get(classDocument);
      final enrollmentSnapshot = await transaction.get(document);
      final canonicalSnapshot = canonicalDocument.path == document.path
          ? enrollmentSnapshot
          : await transaction.get(canonicalDocument);
      if (!classSnapshot.exists || !enrollmentSnapshot.exists) {
        throw StateError('A turma ou matrícula não existe mais.');
      }
      if (canonicalDocument.path != document.path && canonicalSnapshot.exists) {
        throw StateError('Este aluno já está matriculado nesta turma.');
      }

      final classData = classSnapshot.data()!;
      final capacity = classData['capacity'];
      if (capacity is! int || capacity < 1) {
        throw StateError('O limite de vagas da turma é inválido.');
      }
      final storedCount = classData['activeEnrollmentCount'];
      final activeCount = storedCount is int && storedCount >= 0
          ? storedCount
          : initialActiveCount;
      final oldStatus = enrollmentSnapshot.data()?['status'];
      final wasActive = oldStatus == 'active';
      final willBeActive = enrollment.status == 'active';
      final nextCount =
          activeCount + (willBeActive ? 1 : 0) - (wasActive ? 1 : 0);

      if (willBeActive && !wasActive && activeCount >= capacity) {
        throw StateError('Não há vagas disponíveis nesta turma.');
      }

      if (canonicalDocument.path == document.path) {
        transaction.update(document, enrollment.toMap());
      } else {
        transaction.set(canonicalDocument, enrollment.toMap());
        transaction.delete(document);
      }
      transaction.update(classDocument, {
        'activeEnrollmentCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _ensureStudentIsNotEnrolled(
    CollectionReference<Map<String, dynamic>> enrollments,
    String studentId, {
    String? excludingEnrollmentId,
  }) async {
    final existingEnrollments = await enrollments
        .where('studentId', isEqualTo: studentId)
        .get();
    if (existingEnrollments.docs.any(
      (document) => document.id != excludingEnrollmentId,
    )) {
      throw StateError('Este aluno já está matriculado nesta turma.');
    }
  }

  Future<int> _activeEnrollmentCount(
    CollectionReference<Map<String, dynamic>> enrollments,
    Map<String, dynamic> classData,
  ) async {
    final storedCount = classData['activeEnrollmentCount'];
    if (storedCount is int && storedCount >= 0) return storedCount;

    final snapshot = await enrollments.get();
    return snapshot.docs
        .where((document) => document.data()['status'] == 'active')
        .length;
  }

  Stream<List<AttendanceRecord>> watchAttendance(
    String classId,
    DateTime lessonDate,
  ) {
    return _attendanceSession(classId, lessonDate)
        .collection('students')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AttendanceRecord.fromDocument).toList(),
        );
  }

  Future<List<AttendanceLesson>> getAttendanceReport({
    required String classId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final attendance = _organizationDocument
        .collection('classes')
        .doc(classId)
        .collection('attendance');
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day + 1);
    final sessions = await attendance
        .where('lessonDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('lessonDate', isLessThan: Timestamp.fromDate(end))
        .orderBy('lessonDate')
        .get();

    return Future.wait(
      sessions.docs.map((session) async {
        final lessonDate = session.data()['lessonDate'];
        if (lessonDate is! Timestamp) {
          throw FormatException(
            'A aula "${session.id}" está sem uma data válida no Firestore.',
          );
        }
        final students = await session.reference.collection('students').get();
        return AttendanceLesson(
          date: lessonDate.toDate(),
          records: students.docs.map(AttendanceRecord.fromDocument).toList(),
        );
      }),
    );
  }

  Future<void> saveAttendance({
    required String classId,
    required DateTime lessonDate,
    required List<AttendanceRecord> records,
  }) async {
    final session = _attendanceSession(classId, lessonDate);
    final lessonDay = DateTime(
      lessonDate.year,
      lessonDate.month,
      lessonDate.day,
    );
    const batchSize = 450;

    if (records.isEmpty) {
      final batch = _firestore.batch();
      batch.set(session, {
        'lessonDate': Timestamp.fromDate(lessonDay),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return;
    }

    for (var start = 0; start < records.length; start += batchSize) {
      final batch = _firestore.batch();
      if (start == 0) {
        batch.set(session, {
          'lessonDate': Timestamp.fromDate(lessonDay),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final end = (start + batchSize).clamp(0, records.length);
      for (final record in records.sublist(start, end)) {
        batch.set(session.collection('students').doc(record.studentId), {
          'studentId': record.studentId,
          'studentName': record.studentName,
          'present': record.present,
          'markedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  DocumentReference<Map<String, dynamic>> _attendanceSession(
    String classId,
    DateTime lessonDate,
  ) {
    final dateId =
        '${lessonDate.year.toString().padLeft(4, '0')}'
        '${lessonDate.month.toString().padLeft(2, '0')}'
        '${lessonDate.day.toString().padLeft(2, '0')}';
    return _organizationDocument
        .collection('classes')
        .doc(classId)
        .collection('attendance')
        .doc(dateId);
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
