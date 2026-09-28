import '../models/emergency_contact.dart';
import '../services/api_client.dart';

class ContactsRepository {
  final ApiClient _api;
  ContactsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<EmergencyContact>> list() async {
    final response = await _api.get('/emergency-contacts') as List;
    return response.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<EmergencyContact> create(EmergencyContact contact) async {
    final response = await _api.post('/emergency-contacts', contact.toJson());
    return EmergencyContact.fromJson(response as Map<String, dynamic>);
  }

  Future<EmergencyContact> update(EmergencyContact contact) async {
    assert(contact.id != null, 'Cannot update a contact with no id.');
    final response = await _api.put('/emergency-contacts/${contact.id}', contact.toJson());
    return EmergencyContact.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/emergency-contacts/$id');
}
