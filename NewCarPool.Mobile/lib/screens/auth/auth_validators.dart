class AuthValidators {
  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, 'Email');
    if (required != null) {
      return required;
    }

    final email = value!.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email'; // ✅ matches test expectation now
    }
    return null;
  }

  static String? password(String? value) {
    final required = requiredText(value, 'Password');
    if (required != null) {
      return required;
    }

    if (value!.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? phone(String? value) {
    final required = requiredText(value, 'Phone number');
    if (required != null) {
      return required;
    }

    final phone = value!.trim();

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }

    return null;
  }
}
