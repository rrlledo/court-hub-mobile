import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';

class PlayerRegistrationScreen extends StatefulWidget {
  const PlayerRegistrationScreen({super.key, required this.session});
  final Session session;
  @override
  State<PlayerRegistrationScreen> createState() =>
      _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  List<Map<String, dynamic>> facilities = [];
  int? facilityId;
  String search = '';
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadFacilities();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> loadFacilities() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final page = ApiPage.parse(await widget.session.api.request(
          '/registration/facilities',
          query: {if (search.trim().isNotEmpty) 'search': search.trim()}));
      if (mounted) {
        setState(() {
          facilities = page.items;
          facilityId = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = errorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> register() async {
    if (!form.currentState!.validate()) return;
    if (facilityId == null) {
      setState(() => message = 'Select a facility.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.session.registerPlayer(
          facilityId: facilityId!,
          name: name.text,
          email: email.text,
          password: password.text,
          confirmation: confirmation.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => message = errorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create player account')),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                  key: form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Choose a facility with open registration. Your account belongs to its organization.'),
                        const SizedBox(height: 20),
                        TextField(
                            onChanged: (value) => search = value,
                            enabled: !busy,
                            decoration: InputDecoration(
                                labelText: 'Find facility',
                                suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: busy ? null : loadFacilities))),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                            key: ValueKey(facilityId),
                            initialValue: facilityId,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Facility'),
                            items: facilities
                                .map((facility) => DropdownMenuItem(
                                    value: facility['id'] as int,
                                    child: Text(
                                        '${facility['name']}${facility['address'] == null ? '' : ' · ${facility['address']}'}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (value) =>
                                    setState(() => facilityId = value)),
                        if (!busy && facilities.isEmpty)
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'No facilities are accepting new player accounts. Try another name or contact a facility.')),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: name,
                            maxLength: 120,
                            autofillHints: const [AutofillHints.name],
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            validator: required),
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: emailValid),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            validator: (value) =>
                                value == null || value.length < 12
                                    ? 'Use at least 12 characters.'
                                    : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: confirmation,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                                labelText: 'Confirm password'),
                            validator: (value) => value != password.text
                                ? 'Passwords do not match.'
                                : null),
                        if (message != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(message!)),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: busy ? null : register,
                            child: Text(busy
                                ? 'Creating account…'
                                : 'Create player account')),
                        const SizedBox(height: 12),
                        const Text(
                            'We will send a verification link. Confirm your email before making a booking or payment.',
                            textAlign: TextAlign.center),
                      ]))),
        )),
      );
}

String? required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? emailValid(String? value) =>
    value != null && value.contains('@') ? null : 'Enter your email.';
