import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/settings/routes/configuration_external_modules/widgets/address.dart';

/// Protocol dropdown, hostname and optional port tiles for an external module.
class ExternalModuleAddressForm extends StatelessWidget {
  final ExternalModuleAddress address;
  final ValueChanged<ExternalModuleAddress> onChanged;

  ExternalModuleAddressForm({
    Key? key,
    required this.address,
    required this.onChanged,
  }) : super(key: key);

  final GlobalKey<PopupMenuButtonState<String>> _protocolMenuKey =
      GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _protocolTile(),
        _hostnameTile(context),
        _portTile(context),
      ],
    );
  }

  Widget _protocolTile() {
    return LunaBlock(
      title: 'settings.Protocol'.tr(),
      body: [TextSpan(text: address.scheme.toUpperCase())],
      trailing: LunaPopupMenuButton<String>(
        key: _protocolMenuKey,
        tooltip: 'settings.Protocol'.tr(),
        icon: Icons.arrow_drop_down_rounded,
        onSelected: (scheme) => onChanged(address.copyWith(scheme: scheme)),
        itemBuilder: (context) => ExternalModuleAddress.SCHEMES
            .map((scheme) => PopupMenuItem<String>(
                  value: scheme,
                  child: Text(
                    scheme.toUpperCase(),
                    style: TextStyle(
                      fontSize: LunaUI.FONT_SIZE_H3,
                      color: scheme == address.scheme
                          ? LunaColours.accent
                          : Colors.white,
                    ),
                  ),
                ))
            .toList(),
      ),
      onTap: () => _protocolMenuKey.currentState?.showButtonMenu(),
    );
  }

  Widget _hostnameTile(BuildContext context) {
    return LunaBlock(
      title: 'settings.Hostname'.tr(),
      body: [
        TextSpan(
          text: address.hostname.isEmpty
              ? 'lunasea.NotSet'.tr()
              : address.hostname,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> values =
            await SettingsDialogs().editExternalModuleHostname(
          context,
          prefill: address.hostname,
        );
        if (values.item1) onChanged(address.copyWith(hostname: values.item2));
      },
    );
  }

  Widget _portTile(BuildContext context) {
    return LunaBlock(
      title: 'settings.Port'.tr(),
      body: [
        TextSpan(
          text: address.port?.toString() ?? 'settings.PortDefault'.tr(),
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> values =
            await SettingsDialogs().editExternalModulePort(
          context,
          prefill: address.port?.toString() ?? '',
        );
        if (!values.item1) return;
        final port = ExternalModuleAddress.parsePort(values.item2);
        onChanged(port == null
            ? address.copyWith(clearPort: true)
            : address.copyWith(port: port));
      },
    );
  }
}

/// Sends a GET to [url] and reports whether anything answered. Any HTTP
/// response (including 401/403 from an auth wall) counts as reachable.
Future<void> testExternalModuleConnection(String url) async {
  if (url.isEmpty) {
    showLunaErrorSnackBar(
      title: 'settings.HostRequired'.tr(),
      message: 'settings.HostnameRequiredMessage'.tr(),
    );
    return;
  }
  try {
    final response = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (_) => true,
    )).get(url);
    showLunaSuccessSnackBar(
      title: 'settings.ConnectedSuccessfully'.tr(),
      message: 'settings.ExternalModuleReachable'.tr(
        args: [url, '${response.statusCode}'],
      ),
    );
  } catch (error, stack) {
    LunaLogger().error('External module connection test failed', error, stack);
    showLunaErrorSnackBar(
      title: 'settings.ConnectionTestFailed'.tr(),
      error: error,
    );
  }
}
