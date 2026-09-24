/// The pieces of an external module's URL, edited separately in the UI and
/// stored as a single URL string in [LunaExternalModule.host].
class ExternalModuleAddress {
  static const SCHEMES = ['https', 'http'];
  static const DEFAULT_SCHEME = 'https';

  final String scheme;

  /// Hostname or IP address, optionally followed by a path
  /// (e.g. `media.example.com/sonarr` for a reverse-proxied subpath).
  final String hostname;
  final int? port;

  const ExternalModuleAddress({
    this.scheme = DEFAULT_SCHEME,
    this.hostname = '',
    this.port,
  });

  /// Splits a stored URL back into its parts. Values without a scheme (or
  /// unparseable ones) are treated as a bare hostname.
  factory ExternalModuleAddress.parse(String url) {
    final value = url.trim();
    if (value.isEmpty) return const ExternalModuleAddress();

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !SCHEMES.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return ExternalModuleAddress(hostname: value);
    }

    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    String rest = uri.path == '/' ? '' : uri.path;
    if (uri.hasQuery) rest += '?${uri.query}';
    if (uri.hasFragment) rest += '#${uri.fragment}';

    return ExternalModuleAddress(
      scheme: uri.scheme.toLowerCase(),
      hostname: '$host$rest',
      port: uri.hasPort ? uri.port : null,
    );
  }

  bool get isComplete => hostname.isNotEmpty;

  /// The full URL, e.g. `https://media.example.com:8443/sonarr`.
  String get url {
    if (hostname.isEmpty) return '';
    final slash = hostname.indexOf('/');
    final host = slash == -1 ? hostname : hostname.substring(0, slash);
    final path = slash == -1 ? '' : hostname.substring(slash);
    final portSuffix = port == null ? '' : ':$port';
    return '$scheme://$host$portSuffix$path';
  }

  ExternalModuleAddress copyWith({
    String? scheme,
    String? hostname,
    int? port,
    bool clearPort = false,
  }) {
    return ExternalModuleAddress(
      scheme: scheme ?? this.scheme,
      hostname: hostname ?? this.hostname,
      port: clearPort ? null : (port ?? this.port),
    );
  }

  /// A hostname/IP, optionally with a path. It must not include a scheme,
  /// whitespace, or a port (the port has its own field).
  static bool isValidHostname(String value) {
    if (value.isEmpty) return false;
    if (value.contains('://') || RegExp(r'\s').hasMatch(value)) return false;
    final slash = value.indexOf('/');
    final host = slash == -1 ? value : value.substring(0, slash);
    if (host.isEmpty) return false;
    // Bracketed IPv6 literals are the only hosts allowed to contain ':'.
    if (host.startsWith('[')) {
      return host.endsWith(']') && host.length > 2;
    }
    return !host.contains(':');
  }

  /// Returns the port if [value] is a whole number in 1..65535.
  static int? parsePort(String value) {
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) return null;
    return port;
  }
}
