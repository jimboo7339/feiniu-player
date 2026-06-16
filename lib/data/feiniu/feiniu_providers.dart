import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/feiniu_api.dart';
import 'http/fn_dio_client.dart';
import 'repositories/playback_repository.dart';

final fnDioClientProvider = Provider<FnDioClient>((ref) => FnDioClient());

final feiniuApiProvider = Provider<FeiniuApi>((ref) {
  return FeiniuApi(client: ref.watch(fnDioClientProvider));
});

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepository(ref.watch(feiniuApiProvider));
});
