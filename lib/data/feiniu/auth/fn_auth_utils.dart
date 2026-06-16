import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/feiniu_constants.dart';

/// Authx header generation for Feiniu media HTTP API.
class FnAuthUtils {
  FnAuthUtils._();

  static String md5Hex(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  static String generateNonce() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  /// [urlPath] must be the full path, e.g. `/v/api/v1/login`.
  static String genAuthx(String urlPath, String? jsonBody) {
    final nonce = generateNonce();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final dataMd5 = md5Hex(jsonBody ?? '');
    final signStr = [
      FeiniuConstants.apiKey,
      urlPath,
      nonce,
      timestamp,
      dataMd5,
      FeiniuConstants.apiSecret,
    ].join('_');
    final sign = md5Hex(signStr);
    return 'nonce=$nonce&timestamp=$timestamp&sign=$sign';
  }

  static String sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String accountMd5(String account) => md5Hex(account);
}
