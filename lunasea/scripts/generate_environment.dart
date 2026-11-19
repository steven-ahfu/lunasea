import 'dart:io';

Future<void> main() async {
  final environment = Map<String, String>.of(Platform.environment);
  final dotenv = File('../.env');
  if (dotenv.existsSync()) {
    final donationSetting = RegExp(
      r'^\s*(?:export\s+)?(BTC_ADDRESS|MONERO_ADDRESS)\s*=\s*(.*?)\s*$',
    );
    for (final line in dotenv.readAsLinesSync()) {
      final match = donationSetting.firstMatch(line);
      if (match == null) continue;
      final rawValue = match[2]!;
      final value = rawValue.split(RegExp(r'\s+#')).first;
      final address = value.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      environment.putIfAbsent(match[1]!, () => address);
    }
  }
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'environment_config:generate',
  ], environment: environment);
  if (result.exitCode != 0) {
    stderr.writeln('LunaSea environment generation failed.');
    exitCode = result.exitCode;
  }
}
