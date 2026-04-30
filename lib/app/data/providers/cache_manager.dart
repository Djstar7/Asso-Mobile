import 'dart:convert';
import 'package:get_storage/get_storage.dart';

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, _CacheEntry> _memoryCache = {};
  final GetStorage _storage = GetStorage();
  static const int maxCacheSize = 100;
  static const Duration defaultTTL = Duration(minutes: 15);

  /// Get cached data
  T? get<T>(String key) {
    // Check memory cache first
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }

    // Remove expired entry
    if (entry != null && entry.isExpired) {
      _memoryCache.remove(key);
    }

    // Check persistent cache
    final stored = _storage.read('cache_$key');
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored);
        final expiresAt = DateTime.parse(decoded['expires_at']);
        if (expiresAt.isAfter(DateTime.now())) {
          final data = decoded['data'];
          // Also put in memory cache
          _memoryCache[key] = _CacheEntry(data: data, expiresAt: expiresAt);
          return data as T?;
        } else {
          _storage.remove('cache_$key');
        }
      } catch (_) {
        _storage.remove('cache_$key');
      }
    }

    return null;
  }

  /// Set cached data
  void set(String key, dynamic data, {Duration? ttl, bool persist = false}) {
    final expiresAt = DateTime.now().add(ttl ?? defaultTTL);

    // Evict old entries if cache is full
    if (_memoryCache.length >= maxCacheSize) {
      _evictOldest();
    }

    _memoryCache[key] = _CacheEntry(data: data, expiresAt: expiresAt);

    // Persist if requested
    if (persist) {
      try {
        _storage.write('cache_$key', jsonEncode({
          'data': data,
          'expires_at': expiresAt.toIso8601String(),
        }));
      } catch (_) {}
    }
  }

  /// Remove a specific cache entry
  void remove(String key) {
    _memoryCache.remove(key);
    _storage.remove('cache_$key');
  }

  /// Clear all cache (memory and persistent)
  void clearAll() {
    _memoryCache.clear();

    // Clear all persistent cache entries
    try {
      final allKeys = _storage.getKeys();
      for (var key in allKeys) {
        if (key.toString().startsWith('cache_')) {
          _storage.remove(key);
        }
      }
    } catch (_) {
      // Ignore errors during cleanup
    }
  }

  /// Clear expired entries
  void clearExpired() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Evict oldest entries
  void _evictOldest() {
    if (_memoryCache.isEmpty) return;
    final sorted = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));

    // Remove oldest 20%
    final toRemove = (maxCacheSize * 0.2).ceil();
    for (var i = 0; i < toRemove && i < sorted.length; i++) {
      _memoryCache.remove(sorted[i].key);
    }
  }

  /// Check if key exists and is valid
  bool has(String key) {
    final entry = _memoryCache[key];
    return entry != null && !entry.isExpired;
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
