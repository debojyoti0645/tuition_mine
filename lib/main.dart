import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Student {
  final String id;
  String name;
  String classNumber;
  String schoolName;
  String board;
  List<ClassRecord> classes;
  List<FeeRecord> payments;

  Student({
    required this.id,
    required this.name,
    required this.classNumber,
    required this.schoolName,
    required this.board,
    List<ClassRecord>? classes,
    List<FeeRecord>? payments,
  }) : classes = classes ?? [],
       payments = payments ?? [];

  double get totalFeesPaid => payments.fold(0.0, (sum, p) => sum + p.amount);
  int get totalClasses => classes.length;

  // Convert a Student object into a Map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classNumber': classNumber,
    'schoolName': schoolName,
    'board': board,
    'classes': classes.map((c) => c.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  // Create a Student object from a Map.
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      classNumber: json['classNumber'] ?? '',
      schoolName: json['schoolName'] ?? '',
      board: json['board'] ?? '',
      classes:
          (json['classes'] as List<dynamic>?)
              ?.map((c) => ClassRecord.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map((p) => FeeRecord.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ClassRecord {
  final String id;
  final DateTime date;
  String? notes;

  ClassRecord({required this.id, required this.date, this.notes});

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'notes': notes,
  };

  factory ClassRecord.fromJson(Map<String, dynamic> json) {
    return ClassRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }
}

class FeeRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String mode;

  FeeRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'amount': amount,
    'mode': mode,
  };

  factory FeeRecord.fromJson(Map<String, dynamic> json) {
    return FeeRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      amount: json['amount'],
      mode: json['mode'],
    );
  }
}

// New class to hold the backup data and metadata
class BackupData {
  final int version;
  final DateTime exportDate;
  final List<Student> students;

  BackupData({
    required this.version,
    required this.exportDate,
    required this.students,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportDate': exportDate.toIso8601String(),
    'students': students.map((s) => s.toJson()).toList(),
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] ?? 1,
      exportDate: DateTime.parse(json['exportDate']),
      students:
          (json['students'] as List<dynamic>)
              .map((s) => Student.fromJson(s as Map<String, dynamic>))
              .toList(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final studentsString = prefs.getString('students');
    if (studentsString != null) {
      final List<dynamic> studentsJson = jsonDecode(studentsString);
      setState(() {
        students =
            studentsJson
                .map((json) => Student.fromJson(json as Map<String, dynamic>))
                .toList();
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final studentsJson = jsonEncode(students.map((s) => s.toJson()).toList());
    await prefs.setString('students', studentsJson);
  }

  void _addStudent(
    String name,
    String classNumber,
    String schoolName,
    String board,
  ) {
    setState(() {
      students.add(
        Student(
          id: Uuid().v4(),
          name: name,
          classNumber: classNumber,
          schoolName: schoolName,
          board: board,
        ),
      );
      _saveStudents();
    });
  }

  void _updateStudent(Student student) {
    setState(() {
      final index = students.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        students[index] = student;
      }
      _saveStudents();
    });
  }

  void _deleteStudent(Student student) {
    setState(() {
      students.removeWhere((s) => s.id == student.id);
      _saveStudents();
    });
  }

  Future<void> _showAddStudentDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController classNumberController = TextEditingController();
    final TextEditingController schoolNameController = TextEditingController();
    final TextEditingController boardController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Student'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Student Name'),
                  ),
                  TextField(
                    controller: classNumberController,
                    decoration: InputDecoration(labelText: 'Class Number'),
                    keyboardType: TextInputType.text,
                  ),
                  TextField(
                    controller: schoolNameController,
                    decoration: InputDecoration(labelText: 'School Name'),
                  ),
                  TextField(
                    controller: boardController,
                    decoration: InputDecoration(labelText: 'Board'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    _addStudent(
                      nameController.text,
                      classNumberController.text,
                      schoolNameController.text,
                      boardController.text,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  void _navigateToEarningsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EarningsScreen(students: students),
      ),
    );
  }

  void _navigateToSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(onDataRestored: _loadStudents),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _navigateToEarningsScreen,
          child: Text('Student Manager'),
        ),
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: _showAddStudentDialog),
          // New settings button
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _navigateToSettingsScreen,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _buildStudentsTab(),
    );
  }

  Widget _buildStudentsTab() {
    return students.isEmpty
        ? Center(child: Text('No students added yet. Tap + to add a new one.'))
        : ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  student.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Class: ${student.classNumber}, School: ${student.schoolName}',
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StudentDetailScreen(
                            student: student,
                            onUpdate: _updateStudent,
                            onDelete: _deleteStudent,
                          ),
                    ),
                  );
                  setState(() {});
                },
              ),
            );
          },
        );
  }
}

class StudentDetailScreen extends StatefulWidget {
  final Student student;
  final Function(Student) onUpdate;
  final Function(Student) onDelete;

  StudentDetailScreen({
    required this.student,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedClassId;
  String? _selectedPaymentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedClassId = null;
        _selectedPaymentId = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addClass(String notes, DateTime classDateTime) {
    setState(() {
      widget.student.classes.add(
        ClassRecord(id: Uuid().v4(), date: classDateTime, notes: notes),
      );
      widget.onUpdate(widget.student);
    });
  }

  void _editClass(ClassRecord oldClass, DateTime newDate, String newNotes) {
    setState(() {
      final updatedClass = ClassRecord(
        id: oldClass.id,
        date: newDate,
        notes: newNotes,
      );
      final index = widget.student.classes.indexWhere(
        (c) => c.id == oldClass.id,
      );
      if (index != -1) {
        widget.student.classes[index] = updatedClass;
      }
      _selectedClassId = null;
      widget.onUpdate(widget.student);
    });
  }

  void _deleteClass(ClassRecord classRecord) {
    setState(() {
      widget.student.classes.removeWhere((c) => c.id == classRecord.id);
      _selectedClassId = null;
      widget.onUpdate(widget.student);
    });
  }

  void _addPayment(double amount, String mode) {
    setState(() {
      widget.student.payments.add(
        FeeRecord(
          id: Uuid().v4(),
          date: DateTime.now(),
          amount: amount,
          mode: mode,
        ),
      );
      widget.onUpdate(widget.student);
    });
  }

  void _editStudentDetails() async {
    final TextEditingController nameController = TextEditingController(
      text: widget.student.name,
    );
    final TextEditingController classNumberController = TextEditingController(
      text: widget.student.classNumber,
    );
    final TextEditingController schoolNameController = TextEditingController(
      text: widget.student.schoolName,
    );
    final TextEditingController boardController = TextEditingController(
      text: widget.student.board,
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Student Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Student Name'),
                  ),
                  TextField(
                    controller: classNumberController,
                    decoration: InputDecoration(labelText: 'Class Number'),
                  ),
                  TextField(
                    controller: schoolNameController,
                    decoration: InputDecoration(labelText: 'School Name'),
                  ),
                  TextField(
                    controller: boardController,
                    decoration: InputDecoration(labelText: 'Board'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    setState(() {
                      widget.student.name = nameController.text;
                      widget.student.classNumber = classNumberController.text;
                      widget.student.schoolName = schoolNameController.text;
                      widget.student.board = boardController.text;
                    });
                    widget.onUpdate(widget.student);
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  void _deletePayment(FeeRecord payment) {
    setState(() {
      widget.student.payments.removeWhere((p) => p.id == payment.id);
      _selectedPaymentId = null;
      widget.onUpdate(widget.student);
    });
  }

  void _editPayment(FeeRecord oldPayment) async {
    final TextEditingController amountController = TextEditingController(
      text: oldPayment.amount.toString(),
    );
    String selectedMode = oldPayment.mode;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedMode,
                  items:
                      ['Cash', 'Bank Transfer', 'Online'].map((String mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    selectedMode = newValue!;
                  },
                  decoration: InputDecoration(labelText: 'Payment Mode'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (amountController.text.isNotEmpty) {
                    final newPayment = FeeRecord(
                      id: oldPayment.id,
                      date: oldPayment.date,
                      amount: double.parse(amountController.text),
                      mode: selectedMode,
                    );
                    final index = widget.student.payments.indexWhere(
                      (p) => p.id == oldPayment.id,
                    );
                    if (index != -1) {
                      setState(() {
                        widget.student.payments[index] = newPayment;
                        _selectedPaymentId = null;
                      });
                      widget.onUpdate(widget.student);
                      Navigator.pop(context);
                    }
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteStudentConfirmation() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Student'),
          content: Text(
            'Are you sure you want to delete ${widget.student.name} and all their records? This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Delete', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                widget.onDelete(widget.student);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.name),
        actions: [
          IconButton(icon: Icon(Icons.edit), onPressed: _editStudentDetails),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _showDeleteStudentConfirmation,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: 'Classes'), Tab(text: 'Payments')],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _selectedClassId = null;
            _selectedPaymentId = null;
          });
        },
        child: Column(
          children: [
            _buildStudentDetailsCard(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildClassesTab(), _buildPaymentsTab()],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () =>
                _tabController.index == 0
                    ? _showAddClassDialog()
                    : _showAddPaymentDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildStudentDetailsCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            _buildDetailRow(context, 'Name', widget.student.name),
            _buildDetailRow(context, 'Class', widget.student.classNumber),
            _buildDetailRow(context, 'School', widget.student.schoolName),
            _buildDetailRow(context, 'Board', widget.student.board),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: TextStyle(
                fontStyle:
                    value.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    final sortedClasses = widget.student.classes.sortedByDate();
    return Column(
      children: [
        ListTile(
          title: Text(
            'Total Classes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            widget.student.totalClasses.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
        Expanded(
          child:
              sortedClasses.isEmpty
                  ? Center(child: Text('No classes added yet.'))
                  : ListView.builder(
                    itemCount: sortedClasses.length,
                    itemBuilder: (context, index) {
                      final classRecord = sortedClasses[index];
                      final isSelected = _selectedClassId == classRecord.id;
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _selectedClassId =
                                isSelected ? null : classRecord.id;
                          });
                        },
                        child: Stack(
                          children: [
                            Card(
                              elevation: 2,
                              margin: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                title: Text(
                                  'Class on ${DateFormat.yMMMd().format(classRecord.date)}',
                                ),
                                subtitle: Text(classRecord.notes ?? 'No notes'),
                              ),
                            ),
                            Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: isSelected ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 200),
                                curve: Curves.easeIn,
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 30,
                                        ),
                                        onPressed:
                                            () => _showEditClassDialog(
                                              classRecord,
                                            ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                        onPressed:
                                            () => _showDeleteClassConfirmation(
                                              classRecord,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    final sortedPayments = widget.student.payments.sortedByDate();
    return Column(
      children: [
        ListTile(
          title: Text(
            'Total Fees Paid',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            '₹${widget.student.totalFeesPaid.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
        Expanded(
          child:
              sortedPayments.isEmpty
                  ? Center(child: Text('No payments added yet.'))
                  : ListView.builder(
                    itemCount: sortedPayments.length,
                    itemBuilder: (context, index) {
                      final payment = sortedPayments[index];
                      final isSelected = _selectedPaymentId == payment.id;
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _selectedPaymentId = isSelected ? null : payment.id;
                          });
                        },
                        child: Stack(
                          children: [
                            Card(
                              elevation: 2,
                              margin: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                title: Text('Payment of ₹${payment.amount}'),
                                subtitle: Text(
                                  '${DateFormat.yMMMd().format(payment.date)} - ${payment.mode}',
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: isSelected ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 200),
                                curve: Curves.easeIn,
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 20.0,
                                        sigmaY: 10.0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: 30,
                                              ),
                                              onPressed:
                                                  () => _editPayment(payment),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 30,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _showDeletePaymentConfirmation(
                                                        payment,
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Future<void> _showDeletePaymentConfirmation(FeeRecord payment) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Payment'),
          content: Text('Are you sure you want to delete this payment?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _selectedPaymentId = null;
              },
            ),
            ElevatedButton(
              child: Text('Delete', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _deletePayment(payment);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteClassConfirmation(ClassRecord classRecord) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Class'),
          content: Text('Are you sure you want to delete this class record?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _selectedClassId = null;
              },
            ),
            ElevatedButton(
              child: Text('Delete', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _deleteClass(classRecord);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddClassDialog() async {
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Add New Class'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          'Date: ${DateFormat.yMMMd().format(selectedDate)}',
                        ),
                        trailing: Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: Text('Time: ${selectedTime.format(context)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() {
                              selectedTime = time;
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                      ),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Combine date and time before adding
                      final classDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      _addClass(notesController.text, classDateTime);
                      Navigator.pop(context);
                    },
                    child: Text('Add'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _showEditClassDialog(ClassRecord classRecord) async {
    final TextEditingController notesController = TextEditingController(
      text: classRecord.notes,
    );
    DateTime newDate = classRecord.date;
    TimeOfDay newTime = TimeOfDay.fromDateTime(classRecord.date);

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Edit Class Record'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          'Date: ${DateFormat.yMMMd().format(newDate)}',
                        ),
                        trailing: Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: newDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              newDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                newTime.hour,
                                newTime.minute,
                              );
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: Text('Time: ${newTime.format(context)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: newTime,
                          );
                          if (time != null) {
                            setState(() {
                              newTime = time;
                              newDate = DateTime(
                                newDate.year,
                                newDate.month,
                                newDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                      ),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(labelText: 'Notes'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _editClass(classRecord, newDate, notesController.text);
                      Navigator.pop(context);
                    },
                    child: Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _showAddPaymentDialog() async {
    final TextEditingController amountController = TextEditingController();
    String selectedMode = 'Cash';

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedMode,
                  items:
                      ['Cash', 'Bank Transfer', 'Online'].map((String mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    selectedMode = newValue!;
                  },
                  decoration: InputDecoration(labelText: 'Payment Mode'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (amountController.text.isNotEmpty) {
                    _addPayment(
                      double.parse(amountController.text),
                      selectedMode,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDataRestored;

  SettingsScreen({required this.onDataRestored});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isImporting = false;
  bool _isExporting = false;

  Future<void> _exportData(BuildContext context) async {
    setState(() {
      _isExporting = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final studentsString = prefs.getString('students');

    if (studentsString == null || studentsString.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No data to export.')));
      setState(() {
        _isExporting = false;
      });
      return;
    }

    try {
      final studentsJson = jsonDecode(studentsString) as List<dynamic>;
      final studentsList =
          studentsJson
              .map((s) => Student.fromJson(s as Map<String, dynamic>))
              .toList();

      final backupData = BackupData(
        version: 1,
        exportDate: DateTime.now(),
        students: studentsList,
      );

      final fileContent = jsonEncode(backupData.toJson());
      final String fileName =
          'TuitionBackup_${DateFormat('ddMMyy_HHmmss').format(DateTime.now())}.json';

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+ - Use SAF (Storage Access Framework) via FilePicker
          // Convert string to bytes
          final bytes = utf8.encode(fileContent);

          String? outputPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Backup File',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['json'],
            bytes: Uint8List.fromList(bytes), // Pass bytes here
          );

          if (outputPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup saved successfully!')),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Export cancelled')));
          }
        } else {
          // Android 10 and below - Use old method with permission
          var status = await Permission.storage.request();

          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Storage permission is required')),
            );
            setState(() {
              _isExporting = false;
            });
            return;
          }

          final downloadsPath = '/storage/emulated/0/Download';
          final file = File('$downloadsPath/$fileName');
          await file.writeAsString(fileContent);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup saved to Downloads: $fileName')),
          );
        }
      } else {
        // For iOS or other platforms
        final bytes = utf8.encode(fileContent);

        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup File',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(bytes),
        );

        if (outputPath != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Backup saved successfully!')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export data: $e')));
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _importData(BuildContext context) async {
    setState(() {
      _isImporting = true;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          final file = File(filePath);
          final contents = await file.readAsString();
          final decodedData = jsonDecode(contents);
          final backupData = BackupData.fromJson(decodedData);

          final prefs = await SharedPreferences.getInstance();
          final studentsJson = jsonEncode(
            backupData.students.map((s) => s.toJson()).toList(),
          );
          await prefs.setString('students', studentsJson);

          widget.onDataRestored();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data imported successfully!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to import data: $e')));
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // No longer need to request permissions on init, as it's handled in export
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isExporting ? null : () => _exportData(context),
                icon:
                    _isExporting
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(Icons.file_upload),
                label: Text(_isExporting ? 'Exporting...' : 'Export Data'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : () => _importData(context),
                icon:
                    _isImporting
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(Icons.file_download),
                label: Text(_isImporting ? 'Importing...' : 'Import Data'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EarningsScreen extends StatelessWidget {
  final List<Student> students;

  EarningsScreen({required this.students});

  @override
  Widget build(BuildContext context) {
    final allPayments = students.expand((s) => s.payments).toList();
    final allClasses =
        students
            .expand((s) => s.classes.map((c) => {'student': s, 'class': c}))
            .toList();
    final totalEarnings = allPayments.fold(0.0, (sum, p) => sum + p.amount);
    final totalClasses = students.fold(0, (sum, s) => sum + s.totalClasses);

    final paymentsByMonth = <String, double>{};
    final paymentsByYear = <String, double>{};

    for (var payment in allPayments) {
      final monthKey = DateFormat.yMMM().format(payment.date);
      final yearKey = DateFormat.y().format(payment.date);
      paymentsByMonth[monthKey] =
          (paymentsByMonth[monthKey] ?? 0) + payment.amount;
      paymentsByYear[yearKey] = (paymentsByYear[yearKey] ?? 0) + payment.amount;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Earnings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Total Earnings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${totalEarnings.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ClassesListScreen(students: students),
                                ),
                              ),
                          child: Column(
                            children: [
                              Icon(Icons.school, color: Colors.blue),
                              Text('Classes'),
                              Text(
                                totalClasses.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(Icons.attach_money, color: Colors.green),
                            Text('Payments'),
                            Text(
                              allPayments.length.toString(),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildSummarySection(
              context,
              title: 'Earnings by Month',
              data: paymentsByMonth,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => BreakdownScreen(
                            title: 'Earnings by Month',
                            data: paymentsByMonth,
                          ),
                    ),
                  ),
            ),
            SizedBox(height: 16),
            _buildSummarySection(
              context,
              title: 'Earnings by Year',
              data: paymentsByYear,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => BreakdownScreen(
                            title: 'Earnings by Year',
                            data: paymentsByYear,
                          ),
                    ),
                  ),
            ),
            SizedBox(height: 16),
            Text(
              'Recent Payments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Expanded(
              child: ListView(
                children:
                    allPayments.sortedByDate().take(5).map((payment) {
                      return ListTile(
                        title: Text(
                          '${students.firstWhere((s) => s.payments.contains(payment)).name}',
                        ),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(payment.date)} - ${payment.mode}',
                        ),
                        trailing: Text('₹${payment.amount.toStringAsFixed(0)}'),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context, {
    required String title,
    required Map<String, double> data,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          data.entries
              .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
              .join(', '),
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class BreakdownScreen extends StatelessWidget {
  final String title;
  final Map<String, double> data;

  BreakdownScreen({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            data.isEmpty
                ? Center(child: Text('No data available.'))
                : ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final entry = data.entries.elementAt(index);
                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          entry.key,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          '₹${entry.value.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

class ClassesListScreen extends StatefulWidget {
  final List<Student> students;

  ClassesListScreen({required this.students});

  @override
  _ClassesListScreenState createState() => _ClassesListScreenState();
}

class _ClassesListScreenState extends State<ClassesListScreen> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    // Collect all classes with student info
    final allClasses = <Map<String, dynamic>>[];
    for (var student in widget.students) {
      for (var classRecord in student.classes) {
        allClasses.add({'student': student, 'class': classRecord});
      }
    }

    // Filter by selected date if any
    final filteredClasses =
        _selectedDate == null
            ? allClasses
            : allClasses.where((item) {
              final ClassRecord classRecord = item['class'];
              return _isSameDay(classRecord.date, _selectedDate!);
            }).toList();

    // Sort by date (most recent first)
    filteredClasses.sort((a, b) {
      final ClassRecord classA = a['class'];
      final ClassRecord classB = b['class'];
      return classB.date.compareTo(classA.date);
    });

    // Group by day
    final groupedClasses = _groupClassesByDay(filteredClasses);

    return Scaffold(
      appBar: AppBar(
        title: Text('All Classes'),
        actions: [
          IconButton(
            icon: Icon(
              _selectedDate == null ? Icons.filter_list : Icons.filter_list_off,
            ),
            onPressed: _showDateFilterDialog,
            tooltip: _selectedDate == null ? 'Filter by date' : 'Clear filter',
          ),
        ],
      ),
      body:
          filteredClasses.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _selectedDate == null
                          ? 'No classes recorded yet.'
                          : 'No classes on ${DateFormat.yMMMd().format(_selectedDate!)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    if (_selectedDate != null) ...[
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                        child: Text('Clear Filter'),
                      ),
                    ],
                  ],
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 2,
                      color: _selectedDate == null ? null : Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate == null
                                      ? 'Total Classes'
                                      : 'Classes on ${DateFormat.yMMMd().format(_selectedDate!)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  filteredClasses.length.toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedDate != null) ...[
                              SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                },
                                icon: Icon(Icons.clear, size: 16),
                                label: Text('Clear Filter'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: groupedClasses.length,
                      itemBuilder: (context, index) {
                        final dayGroup = groupedClasses[index];
                        final dayLabel = dayGroup['label'] as String;
                        final classes =
                            dayGroup['classes'] as List<Map<String, dynamic>>;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      dayLabel,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${classes.length} class${classes.length == 1 ? '' : 'es'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...classes.map((item) {
                              final Student student = item['student'];
                              final ClassRecord classRecord = item['class'];

                              return Card(
                                elevation: 2,
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      student.name[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    student.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            DateFormat.jm().format(
                                              classRecord.date,
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (classRecord.notes != null &&
                                          classRecord.notes!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            classRecord.notes!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Class ${student.classNumber}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  List<Map<String, dynamic>> _groupClassesByDay(
    List<Map<String, dynamic>> classes,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));

    for (var item in classes) {
      final ClassRecord classRecord = item['class'];
      final classDate = DateTime(
        classRecord.date.year,
        classRecord.date.month,
        classRecord.date.day,
      );

      String key;
      if (_isSameDay(classDate, today)) {
        key = 'Today|${classDate.millisecondsSinceEpoch}';
      } else if (_isSameDay(classDate, yesterday)) {
        key = 'Yesterday|${classDate.millisecondsSinceEpoch}';
      } else {
        key =
            '${DateFormat.yMMMd().format(classDate)}|${classDate.millisecondsSinceEpoch}';
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(item);
    }

    // Convert to list and sort by date
    final result =
        grouped.entries.map((entry) {
          final parts = entry.key.split('|');
          return {
            'label': parts[0],
            'timestamp': int.parse(parts[1]),
            'classes': entry.value,
          };
        }).toList();

    result.sort(
      (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
    );

    return result;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _showDateFilterDialog() async {
    if (_selectedDate != null) {
      // If already filtered, clear the filter
      setState(() {
        _selectedDate = null;
      });
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select date to filter',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}

extension on List<ClassRecord> {
  List<ClassRecord> sortedByDate() {
    final list = List<ClassRecord>.from(this);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

extension on List<FeeRecord> {
  List<FeeRecord> sortedByDate() {
    final list = List<FeeRecord>.from(this);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
