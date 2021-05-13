import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;

import 'src/directory/directory.dart';

export 'src/directory/localstorage_io.dart';

mixin DirUtilsProtocol {
  Stream<Map<String, dynamic>> get stream;
  Future<bool> init([Map<String, dynamic> initialData]);
  dynamic getItem(String key);
  Future<void> setItem(String key, value);
  Future<void> remove(String key);
  Future<void> flush();
  Future<void> clear();
  void dispose();
}

/// Creates instance of a local storage. Key is used as a filename
class LocalStorage {
  Stream<Map<String, dynamic>> get stream => _dir.stream;
  Map<String, dynamic>? _initialData;

  static final Map<String, LocalStorage> _cache = new Map();
  final VoidCallback onInitError;

  late DirUtils _dir;

  /// [ValueNotifier] which notifies about errors during storage initialization
  ValueNotifier<Error> onError = ValueNotifier(Error());

  /// A future indicating if localstorage instance is ready for read/write operations
  late Future<bool> ready;

  /// [key] is used as a filename
  /// Optional [path] is used as a directory. Defaults to application document directory
  factory LocalStorage(String key, [String? path, Map<String, dynamic>? initialData]) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    } else {
      final instance = LocalStorage._internal(
          key, dirUtils, path, initialData, onInitError, debugMode);
      _cache[key] = instance;

      return instance;
    }
  }

  void dispose() {
    _dir.dispose();
  }

  LocalStorage._internal(String key, [String? path, Map<String, dynamic>? initialData]) {
    _dir = DirUtils(key, path);
    _initialData = initialData;

    ready = new Future<bool>(() async {
      this._init();
      return true;
    });
  }

  Future<void> _init() async {
    try {
      await _dir.init(_initialData ?? {});
    } on Error catch (err) {
      onError.value = err;
    }
  }

  /// Returns a value from storage by key
  dynamic getItem(String key) {
    try {
      return _dir.getItem(key);
    } catch (err) {
      onError.value = err;
      return null;
    }
  }

  /// Saves item by [key] to a storage. Value should be json encodable (`json.encode()` is called under the hood).
  /// After item was set to storage, consecutive [getItem] will return `json` representation of this item
  /// if [toEncodable] is provided, it is called before setting item to storage
  /// otherwise `value.toJson()` is called
  Future<void> setItem(
    String key,
    value, [
    Object toEncodable(Object nonEncodable)?,
  ]) async {
    var data = toEncodable?.call(value) ?? null;
    if (data == null) {
      try {
        data = value.toJson();
      } on NoSuchMethodError catch (_) {
        data = value;
      }
    }

    await _dir.setItem(key, data);

    return _flush();
  }

  /// Removes item from storage by key
  Future<void> deleteItem(String key) async {
    await _dir.remove(key);
    return _flush();
  }

  /// Removes all items from localstorage
  Future<void> clear() async {
    await _dir.clear();
    return _flush();
  }

  Future<void> _flush() async {
    try {
      await _dir.flush();
    } catch (e) {
      onError.value = e;
      rethrow;
    }
    return;
  }
}
