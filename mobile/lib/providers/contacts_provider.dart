import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';
import '../repositories/contacts_repository.dart';
import '../services/api_client.dart';

class ContactsProvider extends ChangeNotifier {
  final ContactsRepository _repo;
  ContactsProvider({ContactsRepository? repo}) : _repo = repo ?? ContactsRepository();

  List<EmergencyContact> contacts = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      contacts = await _repo.list();
    } on ApiException catch (e) {
      error = e.message;
    } on ApiUnreachableException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> add(EmergencyContact contact) async {
    try {
      final created = await _repo.create(contact);
      contacts = [...contacts, created]..sort((a, b) => a.priority.compareTo(b.priority));
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.errors != null ? e.errors!.values.first[0] as String : e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(EmergencyContact contact) async {
    try {
      final updated = await _repo.update(contact);
      contacts = [for (final c in contacts) if (c.id == updated.id) updated else c];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.delete(id);
      contacts = contacts.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  EmergencyContact? get primary => contacts.isEmpty
      ? null
      : contacts.reduce((a, b) => a.priority < b.priority ? a : b);
}
