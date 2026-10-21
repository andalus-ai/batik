import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataSource Layer (Patch 031)', () {
    test('MemoryDataSource stores, fetches and emits updates via watch', () async {
      final ds = MemoryDataSource(
        id: 'user_count',
        name: 'User Count',
        initialData: 42,
      );

      final initial = await ds.fetch();
      expect(initial.isOk, isTrue);
      expect(initial.data, 42);

      final emissions = <dynamic>[];
      final sub = ds.watch().listen((result) {
        emissions.add(result.data);
      });

      ds.update(99);
      ds.update(100);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions, [99, 100]);

      await sub.cancel();
      ds.dispose();
    });

    test('DataSourceRegistry manages data sources', () async {
      final registry = DataSourceRegistry.instance;
      final ds = MemoryDataSource(id: 'metrics', name: 'Metrics', initialData: {'cpu': 80});

      registry.register(ds);
      expect(registry.has('metrics'), isTrue);
      expect(registry['metrics']?.name, 'Metrics');

      final res = await registry.fetch('metrics');
      expect(res.data, {'cpu': 80});

      final notFound = await registry.fetch('nonexistent');
      expect(notFound.isOk, isFalse);
    });
  });
}
