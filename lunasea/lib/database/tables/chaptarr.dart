import 'package:lunasea/database/table.dart';

enum ChaptarrDatabase<T> with LunaTableMixin<T> {
  NAVIGATION_INDEX<int>(0),
  HOME_TAB<int>(0),
  FORMAT<String>('ebook'),
  GRID_VIEW<bool>(false),
  CATALOGUE_FILTER<String>('all'),
  SORT_BY_AUTHOR<bool>(false),
  SORT_ASCENDING<bool>(true);

  @override
  LunaTable get table => LunaTable.chaptarr;

  @override
  final T fallback;

  const ChaptarrDatabase(this.fallback);
}
