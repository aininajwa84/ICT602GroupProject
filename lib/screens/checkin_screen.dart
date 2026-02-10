import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _matricController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMatric();
  }

  Future<void> _loadMatric() async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString('matric') ?? '';
    _matricController.text = m;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matric', _matricController.text.trim());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _matricController,
                decoration: const InputDecoration(labelText: 'Matric number'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter matric number';
                  if (value.length != 10) return 'Matric must be exactly 10 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _save, child: const Text('Save'))
            ],
          ),
        ),
      ),
    );
  }
}
