import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'engine_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Native initialization avoids path_provider platform channels in unit tests.
  registerEngineTests(pdfrxInitialize);
}
