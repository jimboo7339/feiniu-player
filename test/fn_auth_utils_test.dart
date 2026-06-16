import 'package:feiniu_player/data/feiniu/auth/fn_auth_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FnAuthUtils', () {
    test('empty body uses md5 of empty string', () {
      final authx1 = FnAuthUtils.genAuthx('/v/api/v1/sys/version', null);
      final authx2 = FnAuthUtils.genAuthx('/v/api/v1/sys/version', '');
      expect(authx1.contains('sign='), isTrue);
      expect(authx2.contains('sign='), isTrue);
    });

    test('genAuthx format', () {
      final authx = FnAuthUtils.genAuthx(
        '/v/api/v1/login',
        '{"app_name":"trimemedia-web","username":"home","password":"x","nonce":"123456"}',
      );
      expect(authx.startsWith('nonce='), isTrue);
      expect(authx.contains('&timestamp='), isTrue);
      expect(authx.contains('&sign='), isTrue);
    });

    test('account md5 is 32 hex chars', () {
      final hash = FnAuthUtils.accountMd5('home');
      expect(hash.length, 32);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });
  });
}
