// lib/admin/components/content_form.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable multi-language content form for CMS
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';

/// Form field configuration
class FormFieldConfig {
  final String key;
  final String labelEn;
  final String labelAr;
  final String? hintEn;
  final String? hintAr;
  final bool required;
  final bool multiline;
  final int minLines;
  final int maxLines;
  final String? value;

  FormFieldConfig({
    required this.key,
    required this.labelEn,
    required this.labelAr,
    this.hintEn,
    this.hintAr,
    this.required = false,
    this.multiline = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.value,
  });
}

class ContentForm extends StatefulWidget {
  const ContentForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.onCancel,
    this.initialValues = const {},
    this.isLoading = false,
    this.submitLabel = 'Save',
  });

  final String title;
  final List<FormFieldConfig> fields;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onCancel;
  final Map<String, dynamic> initialValues;
  final bool isLoading;
  final String submitLabel;

  @override
  State<ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends State<ContentForm> {
  late final Map<String, TextEditingController> _controllers;
  late final GlobalKey<FormState> _formKey;
  bool _isPublished = true;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _controllers = {};

    for (final field in widget.fields) {
      final value = widget.initialValues[field.key] ?? field.value ?? '';
      _controllers[field.key] = TextEditingController(text: value);
    }

    _isPublished = widget.initialValues['isPublished'] ?? true;
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EkkleiciaColors.bgPrimary,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EkkleiciaColors.bgDeep,
              border: Border(
                bottom: BorderSide(
                  color: EkkleiciaColors.goldBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: EkkleciaTheme.headingMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: EkkleiciaColors.textSecondary,
                  ),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),

          // ── Form content ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form fields
                      ...widget.fields.map((field) => _buildField(field)),

                      const SizedBox(height: 24),

                      // Publish toggle
                      _buildPublishToggle(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Footer with actions ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EkkleiciaColors.bgDeep,
              border: Border(
                top: BorderSide(
                  color: EkkleiciaColors.goldBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.isLoading ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EkkleiciaColors.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.isLoading ? null : _submitForm,
                  child: widget.isLoading
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        EkkleiciaColors.bgDeep,
                      ),
                    ),
                  )
                      : Text(widget.submitLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(FormFieldConfig field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: field.labelEn,
                  style: const TextStyle(
                    color: EkkleiciaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (field.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: EkkleiciaColors.maroon,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            field.labelAr,
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkkleiciaColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),

          // Input field
          TextFormField(
            controller: _controllers[field.key],
            minLines: field.minLines,
            maxLines: field.multiline ? field.maxLines : 1,
            validator: field.required
                ? (val) {
              if (val?.isEmpty ?? true) {
                return 'This field is required';
              }
              return null;
            }
                : null,
            style: const TextStyle(
              color: EkkleiciaColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: field.hintEn,
              hintStyle: const TextStyle(
                color: EkkleiciaColors.textSecondary,
                fontSize: 12,
              ),
              filled: true,
              fillColor: EkkleiciaColors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: EkkleiciaColors.goldBorder,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: EkkleiciaColors.gold,
                  width: 1.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: EkkleiciaColors.maroon,
                  width: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EkkleiciaColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EkkleiciaColors.goldBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPublished ? Icons.visibility : Icons.visibility_off,
            color: _isPublished
                ? EkkleiciaColors.gold
                : EkkleiciaColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publish Status',
                  style: TextStyle(
                    color: EkkleiciaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isPublished ? 'Published' : 'Draft',
                  style: const TextStyle(
                    color: EkkleiciaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPublished,
            onChanged: (val) => setState(() => _isPublished = val),
            activeColor: EkkleiciaColors.gold,
            inactiveThumbColor: EkkleiciaColors.textSecondary,
          ),
        ],
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final data = <String, dynamic>{};

      for (final field in widget.fields) {
        data[field.key] = _controllers[field.key]?.text ?? '';
      }

      data['isPublished'] = _isPublished;

      widget.onSubmit(data);
    }
  }
}