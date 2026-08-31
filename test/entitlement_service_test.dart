import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_clipboard/core/database/migrations.dart';
import 'package:smart_clipboard/services/entitlement_service.dart';

void main() {
  // Init sqflite_ffi for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('EntitlementService — Rolling 24h Pro', () {
    late dynamic db;
    late EntitlementService service;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DbMigrations.targetVersion,
          onConfigure: (database) async {
            await database.rawQuery('PRAGMA journal_mode=WAL');
            await database.rawQuery('PRAGMA foreign_keys=ON');
          },
          onCreate: (database, version) =>
              DbMigrations.runInTransaction(database, from: 0, to: version),
        ),
      );
      service = EntitlementService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Initially Pro is NOT active', () async {
      expect(await service.isProActive, false);
    });

    test('Initially expiresAt is null', () async {
      expect(await service.expiresAt, null);
    });

    test('unlockFromRewardedAd → Pro is active', () async {
      await service.unlockFromRewardedAd();
      expect(await service.isProActive, true);
    });

    test('unlockFromRewardedAd → expiresAt is ~24h from now', () async {
      final before = DateTime.now().toUtc();
      await service.unlockFromRewardedAd();
      final after = DateTime.now().toUtc();

      final expires = await service.expiresAt;
      expect(expires, isNotNull);

      // Expiry should be between 23h59m and 24h01m from unlock time
      final diffFromBefore = expires!.difference(before);
      final diffFromAfter = expires.difference(after);

      expect(diffFromBefore.inMinutes, greaterThanOrEqualTo(23 * 60 + 59));
      expect(diffFromAfter.inMinutes, lessThanOrEqualTo(24 * 60 + 1));
    });

    test('unlockFromRewardedAd → stores UTC epoch millis in app_meta', () async {
      await service.unlockFromRewardedAd();

      final rows = await db.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['pro_expiry'],
        limit: 1,
      );

      expect(rows.length, 1);
      final value = rows.first['value'] as String;
      expect(int.tryParse(value), isNotNull);
      expect(int.parse(value), greaterThan(0));
    });

    test('clearPro → Pro is NOT active', () async {
      await service.unlockFromRewardedAd();
      expect(await service.isProActive, true);

      await service.clearPro();
      expect(await service.isProActive, false);
    });

    test('clearPro → expiresAt is null', () async {
      await service.unlockFromRewardedAd();
      expect(await service.expiresAt, isNotNull);

      await service.clearPro();
      expect(await service.expiresAt, null);
    });

    test('clearPro → no row in app_meta', () async {
      await service.unlockFromRewardedAd();
      await service.clearPro();

      final rows = await db.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['pro_expiry'],
      );
      expect(rows.length, 0);
    });

    test('Second unlock resets expiry (rolling)', () async {
      // Unlock first time
      await service.unlockFromRewardedAd();
      final firstExpiry = await service.expiresAt;

      // Unlock second time — expiry should be ~24h from NOW, not cumulative
      await service.unlockFromRewardedAd();
      final secondExpiry = await service.expiresAt;

      // Second expiry should be after first expiry (reset + 24h)
      expect(secondExpiry!.isAfter(firstExpiry!), true);
    });

    test('Pro expires correctly (simulated past expiry)', () async {
      // Manually insert an expired timestamp (1 hour ago)
      final expiredAt = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await db.insert(
        'app_meta',
        {
          'key': 'pro_expiry',
          'value': '${expiredAt.millisecondsSinceEpoch}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, false);
    });

    test('Pro is active with future timestamp', () async {
      final futureAt = DateTime.now().toUtc().add(const Duration(hours: 23));
      await db.insert(
        'app_meta',
        {
          'key': 'pro_expiry',
          'value': '${futureAt.millisecondsSinceEpoch}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, true);
    });

    test('Pro is active at boundary (just before expiry)', () async {
      final almostExpired = DateTime.now().toUtc().add(const Duration(seconds: 1));
      await db.insert(
        'app_meta',
        {
          'key': 'pro_expiry',
          'value': '${almostExpired.millisecondsSinceEpoch}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, true);
    });

    test('Pro is NOT active at boundary (just after expiry)', () async {
      final justExpired = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      await db.insert(
        'app_meta',
        {
          'key': 'pro_expiry',
          'value': '${justExpired.millisecondsSinceEpoch}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, false);
    });

    test('Invalid stored value → Pro NOT active (graceful fallback)', () async {
      await db.insert(
        'app_meta',
        {'key': 'pro_expiry', 'value': 'not_a_number'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, false);
      expect(await service.expiresAt, null);
    });

    test('Empty stored value → Pro NOT active', () async {
      await db.insert(
        'app_meta',
        {'key': 'pro_expiry', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await service.isProActive, false);
    });

    test('Timezone-insensitive: unlock then check from different UTC offset', () async {
      await service.unlockFromRewardedAd();

      final expires = await service.expiresAt;
      expect(expires, isNotNull);
      expect(expires!.isUtc, true);

      // Convert to different timezone — same absolute moment
      final local = expires.toLocal();
      expect(local.millisecondsSinceEpoch, expires.millisecondsSinceEpoch);
    });
  });
}
