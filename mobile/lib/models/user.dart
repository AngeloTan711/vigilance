class User {
  final int id;
  final String name;
  final String email;
  final String? schoolIdNumber;
  final String role; // student | staff | responder | admin
  final String? phone;
  final int schoolId;
  final String status;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.schoolId,
    required this.status,
    this.schoolIdNumber,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      schoolId: json['school_id'] as int,
      status: json['status'] as String? ?? 'active',
      schoolIdNumber: json['school_id_number'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'school_id': schoolId,
        'status': status,
        'school_id_number': schoolIdNumber,
        'phone': phone,
      };

  bool get isStudentOrStaff => role == 'student' || role == 'staff';
}
