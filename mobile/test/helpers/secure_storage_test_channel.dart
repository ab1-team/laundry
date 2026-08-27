import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class SecureStorageTestChannel {
  final Map<String, String> values = {};
  late final TestDefaultBinaryMessengerBinding _binding;

  void install() {
    _binding = TestWidgetsFlutterBinding.ensureInitialized();
    _binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'write':
            final arguments = call.arguments as Map<Object?, Object?>;
            values[arguments['key'] as String] = arguments['value'] as String;
            return null;
          case 'read':
            return values[call.arguments['key'] as String];
          case 'delete':
            values.remove(call.arguments['key'] as String);
            return null;
        }
        return null;
      },
    );
  }
}
