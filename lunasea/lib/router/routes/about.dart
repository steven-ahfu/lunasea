import 'package:flutter/widgets.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/pages/about.dart';

enum AboutRoutes with LunaRoutesMixin {
  PAGE;

  @override
  String get path => '/about';

  @override
  LunaModule? get module => null;

  @override
  bool isModuleEnabled(BuildContext context) => true;

  @override
  GoRoute get routes => route(widget: const LunaAboutPage());
}
