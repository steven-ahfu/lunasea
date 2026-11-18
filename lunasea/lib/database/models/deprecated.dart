import 'package:lunasea/vendor.dart';

part 'deprecated.g.dart';

void registerDeprecatedAdapters() {
  Hive.registerAdapter(Deprecated02Adapter());
  Hive.registerAdapter(Deprecated03Adapter());
  Hive.registerAdapter(Deprecated04Adapter());
  Hive.registerAdapter(Deprecated05Adapter());
  Hive.registerAdapter(Deprecated06Adapter());
  Hive.registerAdapter(Deprecated07Adapter());
  Hive.registerAdapter(Deprecated11Adapter());
}

@HiveType(typeId: 2, adapterName: 'Deprecated02Adapter') // Next: 2
class _Deprecated02 extends HiveObject {}

@HiveType(typeId: 3, adapterName: 'Deprecated03Adapter') // Next: 3
class _Deprecated03 extends HiveObject {}

@HiveType(typeId: 4, adapterName: 'Deprecated04Adapter') // Next: 1
class _Deprecated04 extends HiveObject {}

@HiveType(typeId: 5, adapterName: 'Deprecated05Adapter') // Next: 3
class _Deprecated05 extends HiveObject {}

@HiveType(typeId: 6, adapterName: 'Deprecated06Adapter') // Next: 2
class _Deprecated06 extends HiveObject {}

@HiveType(typeId: 7, adapterName: 'Deprecated07Adapter') // Next: 2
class _Deprecated07 extends HiveObject {}

@HiveType(typeId: 11, adapterName: 'Deprecated11Adapter') // Next: 5
enum _Deprecated11 {
  @HiveField(0)
  DEPRECATED,
}
