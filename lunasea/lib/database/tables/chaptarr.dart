import 'package:lunasea/database/table.dart';

enum ChaptarrDatabase<T> with LunaTableMixin<T> {
  NAVIGATION_INDEX<int>(0);

  @override
  LunaTable get table => LunaTable.chaptarr;

  @override
  final T fallback;

  const ChaptarrDatabase(this.fallback);
}
