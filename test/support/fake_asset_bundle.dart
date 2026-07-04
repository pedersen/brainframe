import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';

/// An in-memory [AssetBundle] over a `key -> content` map, for tests that need
/// locale-partitioned fixtures without shipping them in the app. Overrides
/// [loadStructuredBinaryData] so `AssetManifest.loadFromAssetBundle` returns a
/// manifest listing exactly these keys.
class FakeAssetBundle extends AssetBundle {
  FakeAssetBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final content = files[key];
    if (content == null) throw FlutterError('missing asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) async {
    if (key == 'AssetManifest.bin') {
      return _FakeManifest(files.keys.toList()) as T;
    }
    return super.loadStructuredBinaryData(key, parser);
  }
}

class _FakeManifest implements AssetManifest {
  _FakeManifest(this._keys);
  final List<String> _keys;

  @override
  List<String> listAssets() => _keys;

  @override
  List<AssetMetadata> getAssetVariants(String key) => throw UnimplementedError();
}
