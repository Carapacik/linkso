import 'package:flutter/material.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    Key? key,
    required this.controller,
    this.maxLength,
    this.validator,
    this.onSaved,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
  }) : super(key: key);

  final TextEditingController? controller;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: keyboardType,
      obscureText: obscureText,
      controller: controller,
      maxLength: maxLength,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        filled: true,
        hintText: hintText,
      ),
    );
  }
}
