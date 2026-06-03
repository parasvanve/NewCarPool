import 'package:flutter_test/flutter_test.dart';
import 'package:new_car_pool/screens/auth/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('validates email format', () {
      expect(AuthValidators.email('bad-email'), 'Enter a valid email');
      expect(AuthValidators.email('user@example.com'), isNull);
    });

    test('validates password length', () {
      expect(
        AuthValidators.password('short'),
        'Password must be at least 8 characters',
      );

      expect(AuthValidators.password('long-password'), isNull);
    });
  });
}
