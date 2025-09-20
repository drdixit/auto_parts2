import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/database/database_helper.dart';

Future<void> main() async {
  // ensure DB FFI initialized
  await DatabaseHelper.initializeDatabase();
  final svc = CustomerService();

  // TODO: adjust these IDs to values present in your DB for a meaningful test
  final testCustomerId = 1;
  final testProductId = 1;

  print(
    'Checking last purchased unit price for customer=$testCustomerId product=$testProductId',
  );
  final last = await svc.getLastPurchasedUnitPrice(
    testCustomerId,
    testProductId,
  );
  if (last != null) {
    print('Found last unit price: $last');
  } else {
    print('No prior purchase found for this product/customer.');
  }
}
