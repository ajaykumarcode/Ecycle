import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/pickup_service.dart';
import '../../widgets/ec_auth_shell.dart';

class SchedulePickupScreen extends StatefulWidget {
  const SchedulePickupScreen({super.key});

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _weight = TextEditingController(text: '1');
  final _address = TextEditingController();

  final _pickupService = PickupService();

  static const _categories = [
    'Mobile Phones',
    'Laptops & Computers',
    'Batteries',
    'Televisions & Monitors',
    'Home Appliances',
    'Other Electronics',
  ];

  String _category = _categories.first;
  DateTime _scheduledDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _weight.dispose();
    _address.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate:
          _scheduledDate.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : _scheduledDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Choose your pickup date',
    );

    if (selected != null && mounted) {
      setState(() => _scheduledDate = selected);
    }
  }

  Future<void> _submitPickup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please sign in again.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _pickupService.createPickup(
        token: token,
        category: _category,
        description: _description.text.trim(),
        quantity: int.parse(_quantity.text.trim()),
        estimatedWeightKg: double.parse(_weight.text.trim()),
        pickupAddress: _address.text.trim(),
        scheduledDate: _dateString(_scheduledDate),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup scheduled successfully! ♻️'),
          backgroundColor: ecoGreen,
        ),
      );

      // Return true so the dashboard can refresh its pickup list.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ecoBackground,
      appBar: AppBar(
        title: const Text('Schedule a pickup'),
        backgroundColor: Colors.white,
        foregroundColor: ecoDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE1E9E3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.recycling_rounded,
                          color: ecoGreen,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Give your e-waste a second life.',
                          style: TextStyle(
                            color: ecoDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell us what needs collecting and where we '
                          'should pick it up.',
                          style: TextStyle(color: Colors.black54, height: 1.5),
                        ),
                        const SizedBox(height: 28),

                        _label('E-waste category'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: _decoration(
                            'Choose a category',
                            Icons.devices_other_rounded,
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _category = value);
                                  }
                                },
                        ),

                        const SizedBox(height: 20),
                        _label('Quantity (number of items)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(
                            'e.g. 2',
                            Icons.inventory_2_outlined,
                          ),
                          validator: (value) {
                            final quantity = int.tryParse(value?.trim() ?? '');

                            if (quantity == null ||
                                quantity < 1 ||
                                quantity > 1000) {
                              return 'Enter a whole number between 1 and 1000';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        _label('Estimated weight (kg)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(
                            'e.g. 2.5',
                            Icons.scale_outlined,
                          ),
                          validator: (value) {
                            final weight = double.tryParse(value?.trim() ?? '');

                            if (weight == null ||
                                !weight.isFinite ||
                                weight <= 0 ||
                                weight > 10000) {
                              return 'Enter a weight greater than 0 and at most 10000 kg';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        _label('Pickup address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _address,
                          minLines: 2,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'House/flat, street, area, city, PIN code',
                            Icons.location_on_outlined,
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 8) {
                              return 'Enter a more complete pickup address';
                            }
                            if ((value?.trim().length ?? 0) > 300) {
                              return 'Address must be 300 characters or fewer';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        _label('Pickup date'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _isSubmitting ? null : _chooseDate,
                          borderRadius: BorderRadius.circular(13),
                          child: InputDecorator(
                            decoration: _decoration(
                              'Choose date',
                              Icons.calendar_month_outlined,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_scheduledDate.day.toString().padLeft(2, '0')}/'
                                    '${_scheduledDate.month.toString().padLeft(2, '0')}/'
                                    '${_scheduledDate.year}',
                                    style: const TextStyle(
                                      color: ecoDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_calendar_outlined,
                                  color: ecoGreen,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        _label('Additional details'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'Describe the items or any pickup instructions',
                            Icons.notes_rounded,
                          ),
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitPickup,
                            style: FilledButton.styleFrom(
                              backgroundColor: ecoGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    height: 19,
                                    width: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.calendar_month_rounded),
                            label: Text(
                              _isSubmitting
                                  ? 'Scheduling pickup...'
                                  : 'Confirm pickup',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _label(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: ecoDark,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );
}

InputDecoration _decoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: Colors.black45),
    filled: true,
    fillColor: const Color(0xFFFAFCFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFE1E9E3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFE1E9E3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: ecoGreen, width: 1.5),
    ),
    errorMaxLines: 3,
  );
}
