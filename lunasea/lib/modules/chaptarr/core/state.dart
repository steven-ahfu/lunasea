import 'package:lunasea/api/chaptarr/chaptarr.dart';
import 'package:lunasea/core.dart';

class ChaptarrState extends LunaModuleState {
  ChaptarrState() {
    reset();
  }

  bool enabled = false;
  ChaptarrAPI? api;

  @override
  void reset() {
    final profile = LunaProfile.current;
    enabled = profile.chaptarrEnabled;
    api?.close();
    api =
        enabled &&
            profile.chaptarrHost.trim().isNotEmpty &&
            profile.chaptarrKey.trim().isNotEmpty
        ? ChaptarrAPI.from(profile)
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    api?.close();
    super.dispose();
  }
}
