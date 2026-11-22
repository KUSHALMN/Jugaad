import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/core/network/dio_client.dart';
import 'package:jugaad_mvp/core/services/fast_storage_service.dart';
import 'package:jugaad_mvp/core/services/location_service.dart';
import 'package:jugaad_mvp/core/utils/search_debouncer.dart';
import 'package:jugaad_mvp/features/shared/widgets/app_optimized_network_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance: FastStorageService L1 Memory Cache Tests', () {
    final storage = FastStorageService.instance;

    setUp(() async {
      await storage.clear();
    });

    test('Synchronously stores and retrieves primitive values without async delay', () async {
      await storage.setString('test_key', 'jugaad_pro');
      await storage.setBool('is_online', true);
      await storage.setInt('streak_count', 7);
      await storage.setDouble('wallet_balance', 450.50);

      expect(storage.getString('test_key'), equals('jugaad_pro'));
      expect(storage.getBool('is_online'), isTrue);
      expect(storage.getInt('streak_count'), equals(7));
      expect(storage.getDouble('wallet_balance'), equals(450.50));
    });

    test('Returns default fallback values when keys are absent', () {
      expect(storage.getString('absent_key', defaultValue: 'default_val'), equals('default_val'));
      expect(storage.getBool('absent_flag', defaultValue: true), isTrue);
      expect(storage.getInt('absent_int', defaultValue: 42), equals(42));
      expect(storage.getDouble('absent_double', defaultValue: 99.9), equals(99.9));
    });

    test('Correctly tracks containsKey and removes items synchronously', () async {
      await storage.setString('temp_key', 'hello');
      expect(storage.containsKey('temp_key'), isTrue);

      await storage.remove('temp_key');
      expect(storage.containsKey('temp_key'), isFalse);
      expect(storage.getString('temp_key'), isNull);
    });
  });

  group('Performance: SearchDebouncer & Query Memoization Tests', () {
    test('Debouncer throttles rapid calls and executes only trailing query', () async {
      final debouncer = SearchDebouncer<String>(delay: const Duration(milliseconds: 50));
      String? finalResult;
      int executionCount = 0;

      // Simulate rapid keystrokes: 'p', 'pl', 'plu', 'plumb'
      final queries = ['p', 'pl', 'plu', 'plumb'];
      for (final q in queries) {
        debouncer.run(
          query: q,
          action: () async {
            executionCount++;
            return 'results_for_$q';
          },
          onResult: (result, fromCache) {
            finalResult = result;
          },
        );
      }

      // Wait past debounce window
      await Future.delayed(const Duration(milliseconds: 80));

      expect(executionCount, equals(1));
      expect(finalResult, equals('results_for_plumb'));
      expect(debouncer.isMemoized('plumb'), isTrue);

      debouncer.dispose();
    });

    test('Query memoization returns immediately from cache without delay', () async {
      final debouncer = SearchDebouncer<String>(delay: const Duration(milliseconds: 50));
      int networkHits = 0;

      // Prime the cache
      debouncer.run(
        query: 'electrician',
        action: () async {
          networkHits++;
          return 'electrician_data';
        },
        onResult: (_, __) {},
      );

      await Future.delayed(const Duration(milliseconds: 80));
      expect(networkHits, equals(1));

      // Query again: should be immediate cache hit without invoking action callback
      bool returnedFromCache = false;
      String? cachedResult;
      debouncer.run(
        query: 'electrician',
        action: () async {
          networkHits++;
          return 'electrician_data_2';
        },
        onResult: (result, fromCache) {
          returnedFromCache = fromCache;
          cachedResult = result;
        },
      );

      expect(returnedFromCache, isTrue);
      expect(cachedResult, equals('electrician_data'));
      expect(networkHits, equals(1)); // No extra network hit

      debouncer.dispose();
    });
  });

  group('Performance: DioClient LRU Cache Telemetry Tests', () {
    test('DioClient exposes live cache metrics and invalidation', () {
      DioClient.initialize();
      final stats = DioClient.getCacheStats();

      expect(stats, contains('hits'));
      expect(stats, contains('misses'));
      expect(stats, contains('evictions'));
      expect(stats, contains('entries'));
      expect(stats, contains('hitRatioPercent'));

      DioClient.invalidateCache();
      final clearedStats = DioClient.getCacheStats();
      expect(clearedStats['entries'], equals(0));
    });
  });

  group('Performance: LocationService Battery Throttling Tests', () {
    test('LocationService exposes battery optimization statistics', () {
      final locationService = LocationService();
      final stats = locationService.getOptimizationStats();

      expect(stats, contains('totalPositionsReceived'));
      expect(stats, contains('suppressedUpdatesCount'));
      expect(stats, contains('dbWritesPerformed'));
      expect(stats, contains('batteryNetworkSavingsPercent'));
      expect(stats, contains('trackingMode'));
    });

    test('TrackingMode switches interval thresholds correctly', () {
      final locationService = LocationService();
      locationService.setTrackingMode(TrackingMode.enRoute);
      expect(locationService.trackingMode, equals(TrackingMode.enRoute));

      locationService.setTrackingMode(TrackingMode.inProgress);
      expect(locationService.trackingMode, equals(TrackingMode.inProgress));

      locationService.setTrackingMode(TrackingMode.idle);
      expect(locationService.trackingMode, equals(TrackingMode.idle));
    });
  });

  group('Performance: AppOptimizedNetworkImage Widget Tests', () {
    testWidgets('Renders initials fallback safely when image URL is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppOptimizedNetworkImage(
              imageUrl: '',
              width: 50,
              height: 50,
              fallbackInitials: 'KM',
            ),
          ),
        ),
      );

      expect(find.text('KM'), findsOneWidget);
    });

    testWidgets('Renders custom fallback widget when provided and URL is invalid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppOptimizedNetworkImage(
              imageUrl: 'invalid-url',
              width: 60,
              height: 60,
              fallbackWidget: Icon(Icons.handyman_rounded, key: Key('custom_fallback')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom_fallback')), findsOneWidget);
    });
  });
}
