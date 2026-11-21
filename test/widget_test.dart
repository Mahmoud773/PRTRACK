import 'package:flutter_test/flutter_test.dart';
import 'package:prtrack/src/l10n/s.dart';

void main() {
  test('success banner names the purchase order', () {
    expect(S(true).updatedOk('PO-1'), 'تم التحديث بنجاح PO-1');
    expect(S(false).updatedOk('PO-1'), 'Updated successfully PO-1');
  });
}
