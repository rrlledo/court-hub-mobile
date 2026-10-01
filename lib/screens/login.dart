import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import 'player_registration.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final Session session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (reset ? !email.text.contains('@') : !form.currentState!.validate()) {
      if (reset) setState(() => message = 'Enter your email address first.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (reset) {
        await widget.session.api.request('/auth/forgot-password',
            method: 'POST', data: {'email': email.text.trim()});
        if (mounted) {
          setState(() =>
              message = 'If the account exists, a reset link has been sent.');
        }
      } else {
        await widget.session.login(email.text, password.text, code.text);
      }
    } catch (error) {
      if (mounted) setState(() => message = errorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> socialLogin() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.session.loginWithMockGoogle(code.text);
    } catch (error) {
      if (mounted) setState(() => message = errorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                  child: Form(
                      key: form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.sports_tennis,
                                size: 56, color: Color(0xff176b50)),
                            const SizedBox(height: 20),
                            Text('Court Hub',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineLarge),
                            const SizedBox(height: 8),
                            const Text('Your next game starts here.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 32),
                            TextFormField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                decoration:
                                    const InputDecoration(labelText: 'Email'),
                                validator: (v) => v != null && v.contains('@')
                                    ? null
                                    : 'Enter your email.'),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: password,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                decoration: const InputDecoration(
                                    labelText: 'Password'),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your password.'
                                    : null),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: code,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Authenticator code (if enabled)'),
                                onFieldSubmitted: (_) {
                                  if (!busy) submit();
                                }),
                            if (message != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child:
                                      Text(message!, semanticsLabel: message)),
                            const SizedBox(height: 20),
                            FilledButton(
                                onPressed: busy ? null : submit,
                                child: Text(busy ? 'Please wait…' : 'Sign in')),
                            OutlinedButton.icon(
                                onPressed: busy ? null : socialLogin,
                                icon: const Icon(Icons.account_circle_outlined),
                                label: const Text(
                                    'Sign in with Google (local mock)')),
                            const Text(
                                'Uses the seeded demo player and never contacts Google.',
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed:
                                    busy ? null : () => submit(reset: true),
                                child: const Text('Forgot password?')),
                            const SizedBox(height: 20),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    PlayerRegistrationScreen(
                                                        session:
                                                            widget.session)));
                                      },
                                child: const Text('Create a player account')),
                            const Text(
                                'Facility owners create staff accounts on the web.',
                                textAlign: TextAlign.center),
                          ]))),
            )),
      )));
}
