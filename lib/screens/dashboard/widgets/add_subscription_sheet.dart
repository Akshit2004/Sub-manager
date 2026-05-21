import 'package:flutter/material.dart';
import '../../../services/mongodb_service.dart';
import '../../../utils/currency_utils.dart';

class AddSubSheet extends StatefulWidget {
  final String userEmail;
  final VoidCallback onSaved;
  final Map<String, dynamic>? existingSub;

  const AddSubSheet({
    super.key,
    required this.userEmail,
    required this.onSaved,
    this.existingSub,
  });

  @override
  State<AddSubSheet> createState() => _AddSubSheetState();
}

class _AddSubSheetState extends State<AddSubSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  String _currency = 'USD';
  String _category = 'Entertainment';
  String _hexColor = 'FFE50914';
  bool _saving = false;

  List<Map<String, dynamic>> _userGroups = [];
  String? _selectedGroupId;
  bool _loadingGroup = true;
  bool _shareWithFamily = false;

  final List<(String, String)> _categories = [
    ('Entertainment', 'FFE50914'),
    ('Software', 'FFA259FF'),
    ('Utility', 'FF3395FF'),
    ('Other', 'FF6B6B80'),
  ];

  bool get _isEditMode => widget.existingSub != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final sub = widget.existingSub!;
      _nameCtrl.text = sub['name'] ?? '';
      _planCtrl.text = sub['plan'] ?? '';
      _priceCtrl.text = (sub['price'] as num?)?.toString() ?? '';
      _dateCtrl.text = sub['renewalDate'] ?? '';
      _currency = (sub['currency'] ?? 'USD').toString().toUpperCase();
      _category = sub['category'] ?? 'Entertainment';
      _hexColor = sub['color'] ?? 'FF6B6B80';
      _selectedGroupId = sub['groupId'];
      _shareWithFamily = sub['groupId'] != null;
      _loadingGroup = false;
    }
    _checkUserGroup();
  }

  Future<void> _checkUserGroup() async {
    try {
      final groups = await MongoDbService().getUserGroups(widget.userEmail);
      if (mounted) {
        setState(() {
          _userGroups = groups;
          if (groups.isNotEmpty) {
            _selectedGroupId = groups[0]['id'];
          }
          _loadingGroup = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingGroup = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _planCtrl.dispose();
    _priceCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4593A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dateCtrl.text = '${months[picked.month - 1]} ${picked.day}';
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'plan': _planCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 0.0,
      'currency': _currency,
      'renewalDate': _dateCtrl.text.trim(),
      'category': _category,
      'color': _hexColor,
      if (_shareWithFamily && _selectedGroupId != null) 'groupId': _selectedGroupId,
    };

    bool result;
    if (_isEditMode) {
      final sub = widget.existingSub!;
      final subId = (sub['_id'] != null)
          ? sub['_id'].toString().replaceAll('ObjectId("', '').replaceAll('")', '')
          : (sub['id'] ?? sub['createdAt'] ?? '').toString();
      result = await MongoDbService().updateSubscription(widget.userEmail, subId, data);
    } else {
      result = await MongoDbService().addSubscription(widget.userEmail, data);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result) {
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save subscription. Check connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? 'Edit Subscription' : 'Add New Subscription',
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B80)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _input(_nameCtrl, 'Subscription Name', 'e.g. Netflix, Spotify', Icons.receipt_long_rounded),
              const SizedBox(height: 16),
              _input(_planCtrl, 'Plan Details', 'e.g. Standard Plan, Premium Duo', Icons.dns_rounded),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: _input(
                      _priceCtrl,
                      'Price',
                      'e.g. 15.49',
                      Icons.attach_money_rounded,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 9,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E4DE)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Cur',
                            labelStyle: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w500, fontSize: 11),
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B6B80)),
                          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 13.5),
                          dropdownColor: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _currency = val;
                              });
                            }
                          },
                          items: CurrencyUtils.currencySymbols.keys.map((String cur) {
                            final symbol = CurrencyUtils.currencySymbols[cur] ?? '';
                            return DropdownMenuItem<String>(
                              value: cur,
                              child: Text('$symbol $cur'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _input(
                    _dateCtrl,
                    'Renewal Date',
                    'e.g. Jun 15',
                    Icons.calendar_month_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Category & Theme',
                style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final active = _category == cat.$1;
                  final chipColor = Color(int.parse(cat.$2, radix: 16));
                  return ChoiceChip(
                    label: Text(cat.$1),
                    selected: active,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _category = cat.$1;
                          _hexColor = cat.$2;
                        });
                      }
                    },
                    selectedColor: chipColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: active ? chipColor : const Color(0xFF6B6B80),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: active ? chipColor : const Color(0xFFE8E4DE)),
                    ),
                  );
                }).toList(),
              ),
              if (!_loadingGroup && _userGroups.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4593A).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4593A).withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        value: _shareWithFamily,
                        onChanged: (val) {
                          setState(() {
                            _shareWithFamily = val;
                          });
                        },
                        activeColor: const Color(0xFFD4593A),
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.people_alt_rounded, color: Color(0xFFD4593A)),
                        title: const Text(
                          'Share with Family Group',
                          style: TextStyle(
                            color: Color(0xFF1A1A2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Allow members of the selected family to view and sync this plan.',
                          style: TextStyle(
                            color: Color(0xFF6B6B80),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (_shareWithFamily && _userGroups.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedGroupId,
                          items: _userGroups.map((g) {
                            return DropdownMenuItem<String>(
                              value: g['id'],
                              child: Text(
                                g['name'] ?? 'Family Group',
                                style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedGroupId = val;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select Family Group',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ] else if (_shareWithFamily && _userGroups.length == 1) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text(
                            'Sharing to: ${_userGroups[0]['name']}',
                            style: const TextStyle(
                              color: Color(0xFFD4593A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4593A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _isEditMode ? 'Update Subscription' : 'Save Subscription',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFACA8A1), fontWeight: FontWeight.w400, fontSize: 13.5),
        labelStyle: const TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w500, fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFFD4593A), size: 19),
        filled: true,
        fillColor: const Color(0xFFFAF9F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4593A), width: 1.5),
        ),
      ),
    );
  }
}
