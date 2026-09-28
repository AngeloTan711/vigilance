import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/emergency_contact.dart';
import '../../providers/contacts_provider.dart';
import '../../utils/validators.dart';

class ContactFormScreen extends StatefulWidget {
  final EmergencyContact? existing;
  const ContactFormScreen({super.key, this.existing});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _relationshipCtrl;
  late final TextEditingController _priorityCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _relationshipCtrl = TextEditingController(text: e?.relationship ?? '');
    _priorityCtrl = TextEditingController(text: (e?.priority ?? 1).toString());
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ContactsProvider>();
    final contact = EmergencyContact(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      relationship: _relationshipCtrl.text.trim(),
      priority: int.tryParse(_priorityCtrl.text.trim()) ?? 1,
    );
    final ok = widget.existing == null ? await provider.add(contact) : await provider.update(contact);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Contact' : 'Edit Contact')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => Validators.required(v, field: 'Name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _relationshipCtrl,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priorityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Priority (1 = primary)'),
                  validator: (v) => Validators.required(v, field: 'Priority'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _onSave, child: const Text('SAVE')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
