import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import '../test/engine_contract.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerEngineTests(pdfrxFlutterInitialize, integration: true);
}
