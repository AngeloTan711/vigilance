import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/emergency_contact.dart';
import '../../providers/contacts_provider.dart';
import 'contact_form_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ContactsProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('ADD CONTACT'),
      ),
      body: contacts.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.contacts.isEmpty
              ? const Center(child: Text('No emergency contacts yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.contacts.length,
                  itemBuilder: (context, i) {
                    final EmergencyContact c = contacts.contacts[i];
                    return Card(
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text('${c.relationship ?? ''} · ${c.phone}'),
                        leading: c.isPrimary
                            ? const Icon(Icons.star, color: Colors.amber)
                            : const Icon(Icons.person_outline),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => contacts.delete(c.id!),
                        ),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => ContactFormScreen(existing: c))),
                      ),
                    );
                  },
                ),
    );
  }
}
