import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationChaptarrRoute extends StatefulWidget {
  const ConfigurationChaptarrRoute({super.key});

  @override
  State<ConfigurationChaptarrRoute> createState() => _State();
}

class _State extends State<ConfigurationChaptarrRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar() as PreferredSizeWidget?,
      body: _body(),
      bottomNavigationBar: _bottomActionBar(),
    );
  }

  Widget _appBar() {
    return LunaAppBar(
      title: LunaModule.CHAPTARR.title,
      scrollControllers: [scrollController],
    );
  }

  Widget _bottomActionBar() {
    return LunaBottomActionBar(actions: [_testConnection()]);
  }

  Widget _body() {
    return LunaBox.profiles.listenableBuilder(
      builder: (context, _) => LunaListView(
        controller: scrollController,
        children: [
          LunaModule.CHAPTARR.informationBanner(),
          LunaBlock(
            title: 'settings.EnableModule'.tr(
              args: [LunaModule.CHAPTARR.title],
            ),
            trailing: LunaSwitch(
              value: LunaProfile.current.chaptarrEnabled,
              onChanged: (enabled) {
                LunaProfile.current.chaptarrEnabled = enabled;
                LunaProfile.current.save();
                context.read<ChaptarrState>().reset();
              },
            ),
          ),
          _host(),
          _apiKey(),
          _customHeaders(),
        ],
      ),
    );
  }

  Widget _host() {
    String host = LunaProfile.current.chaptarrHost;
    return LunaBlock(
      title: 'settings.Host'.tr(),
      body: [TextSpan(text: host.isEmpty ? 'lunasea.NotSet'.tr() : host)],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await SettingsDialogs().editHost(
          context,
          prefill: host,
        );
        if (context.mounted && _values.item1) {
          LunaProfile.current.chaptarrHost = _values.item2.trim();
          LunaProfile.current.save();
          context.read<ChaptarrState>().reset();
        }
      },
    );
  }

  Widget _apiKey() {
    String apiKey = LunaProfile.current.chaptarrKey;
    return LunaBlock(
      title: 'settings.ApiKey'.tr(),
      body: [
        TextSpan(
          text: apiKey.isEmpty
              ? 'lunasea.NotSet'.tr()
              : LunaUI.TEXT_OBFUSCATED_PASSWORD,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await LunaDialogs().editText(
          context,
          'settings.ApiKey'.tr(),
          prefill: apiKey,
        );
        if (context.mounted && _values.item1) {
          LunaProfile.current.chaptarrKey = _values.item2.trim();
          LunaProfile.current.save();
          context.read<ChaptarrState>().reset();
        }
      },
    );
  }

  Widget _testConnection() {
    return LunaButton.text(
      text: 'settings.TestConnection'.tr(),
      icon: Icons.wifi_tethering_rounded,
      onTap: () async {
        LunaProfile _profile = LunaProfile.current;
        if (_profile.chaptarrHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'.tr(
              args: [LunaModule.CHAPTARR.title],
            ),
          );
          return;
        }
        if (_profile.chaptarrKey.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.ApiKeyRequired'.tr(),
            message: 'settings.ApiKeyRequiredMessage'.tr(
              args: [LunaModule.CHAPTARR.title],
            ),
          );
          return;
        }
        final api = ChaptarrAPI.from(_profile);
        try {
          await api.testConnection();
          if (!context.mounted) return;
          showLunaSuccessSnackBar(
            title: 'settings.ConnectedSuccessfully'.tr(),
            message: 'settings.ConnectedSuccessfullyMessage'.tr(
              args: [LunaModule.CHAPTARR.title],
            ),
          );
        } catch (error) {
          if (!context.mounted) return;
          showLunaErrorSnackBar(
            title: 'settings.ConnectionTestFailed'.tr(),
            error: error,
          );
        } finally {
          api.close();
        }
      },
    );
  }

  Widget _customHeaders() {
    return LunaBlock(
      title: 'settings.CustomHeaders'.tr(),
      body: [TextSpan(text: 'settings.CustomHeadersDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_CHAPTARR_HEADERS.go,
    );
  }
}
