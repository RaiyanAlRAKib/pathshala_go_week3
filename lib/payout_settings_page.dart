import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'payout_service.dart';
import 'widgets/loading_button.dart';

class PayoutSettingsPage extends StatefulWidget {
  const PayoutSettingsPage({super.key});

  @override
  State<PayoutSettingsPage> createState() => _PayoutSettingsPageState();
}

class _PayoutSettingsPageState extends State<PayoutSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _service = PayoutService();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    try {
      final number = await _service.fetchBkashNumber();
      if (!mounted) return;
      if (number != null) _numberController.text = number;
    } catch (e) {
      if (mounted) _showMessage('Could not load your saved number.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your bKash number';
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(value.trim())) {
      return 'Enter a valid 11-digit number, e.g. 01712345678';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.saveBkashNumber(_numberController.text.trim());
      if (!mounted) return;
      _showMessage('bKash number saved.');
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Student payments are collected by PathshalaGo. '
                        'Your earnings will be sent to the bKash number below.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numberController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'bKash number',
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_android_outlined),
                        counterText: '',
                      ),
                      validator: _validate,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use a personal bKash account that you own.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    LoadingButton(label: 'Save', isLoading: _isSaving, onPressed: _save),
                  ],
                ),
              ),
            ),
    );
  }
}