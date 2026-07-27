import 'package:PiliPlus/models/common/video/cdn_accelerator.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/services/cdn_accelerator_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';

abstract final class VideoUtils {
  static String getCdnUrl(Iterable<String> urls, {bool isAudio = false}) =>
      resolveCdnUrl(urls).primaryUrl;

  static CdnResolution resolveCdnUrl(
    Iterable<String> urls, {
    String? avoidHost,
    bool probe = true,
  }) => CdnAcceleratorService.instance.resolve(
    urls,
    avoidHost: avoidHost,
    probe: probe,
  );

  static String getLiveCdnUrl(CodecItem e, {int index = 0}) {
    final usable = CdnAcceleratorService.instance.usableLiveIndexes([
      for (final item in e.urlInfo) (host: item.host, extra: item.extra),
    ]);
    final selectedIndex = usable.contains(index) ? index : usable.first;
    final urlInfo = e.urlInfo.getOrFirst(selectedIndex);
    return urlInfo.host + e.baseUrl + urlInfo.extra;
  }

  static VideoDecodeFormatType selectCodec(
    Iterable<String> codecs,
    List<VideoDecodeFormatType> preferCodecs,
  ) {
    if (preferCodecs.isNotEmpty) {
      int bestIndex = preferCodecs.length;
      for (final e in codecs) {
        for (int i = 0; i < bestIndex; i++) {
          if (preferCodecs[i].codes.any(e.startsWith)) {
            bestIndex = i;
            if (bestIndex == 0) {
              return preferCodecs[0];
            }
            break;
          }
        }
      }
      if (bestIndex < preferCodecs.length) {
        return preferCodecs[bestIndex];
      }
    }
    return VideoDecodeFormatType.fromString(codecs.first);
  }
}
