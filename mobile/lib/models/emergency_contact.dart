class EmergencyContact {
  final int? id; // null until saved to backend
  final String name;
  final String phone;
  final String? relationship;
  final int priority; // 1 = primary

  EmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    this.relationship,
    required this.priority,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'priority': priority,
      };

  EmergencyContact copyWith({
    int? id,
    String? name,
    String? phone,
    String? relationship,
    int? priority,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
    );
  }

  bool get isPrimary => priority == 1;
}
