import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/system/environment.dart';
import 'package:lunasea/widgets/ui/assets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _repository = 'https://github.com/steven-ahfu/lunasea';

const _donations = [
  _Donation('Monero (XMR)', 'monero', LunaEnvironment.moneroAddress),
  _Donation('Bitcoin (BTC)', 'bitcoin', LunaEnvironment.bitcoinAddress),
];

class LunaAboutPage extends StatefulWidget {
  const LunaAboutPage({super.key});

  @override
  State<LunaAboutPage> createState() => _LunaAboutPageState();
}

class _LunaAboutPageState extends State<LunaAboutPage> {
  late final _packageInfo = PackageInfo.fromPlatform();
  final _donationPages = PageController();
  final _availableDonations = _donations
      .where((donation) => donation.address.isNotEmpty)
      .toList(growable: false);
  int _selectedDonation = 0;

  @override
  void dispose() {
    _donationPages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('lunasea.About'.tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Image.asset(LunaAssets.brandingLogo, height: 80, width: 80),
                const SizedBox(height: 16),
                Text(
                  'LunaSea',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                FutureBuilder<PackageInfo>(
                  future: _packageInfo,
                  builder: (context, snapshot) =>
                      _releaseInfo(context, snapshot.data?.version),
                ),
                if (_availableDonations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'lunasea.SupportDevelopment'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('lunasea.DonationInstructions'.tr()),
                  const SizedBox(height: 16),
                  _donationCarousel(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _releaseInfo(BuildContext context, String? version) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (version != null && version.isNotEmpty)
          Text(
            'v$version',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        Text('lunasea.AboutDescription'.tr(), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.code_rounded),
            label: Text('lunasea.SourceCode'.tr()),
            onPressed: () => _repository.openLink(),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'lunasea.Changelog'.tr(),
                  style: theme.textTheme.titleLarge,
                ),
                if (version == '1.3.4') ...[
                  const SizedBox(height: 8),
                  Text(
                    'v1.3.4  ·  2026-11-19',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'lunasea.Release134Title'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('•  ${'lunasea.Release134Library'.tr()}'),
                  const SizedBox(height: 6),
                  Text('•  ${'lunasea.Release134Search'.tr()}'),
                  const SizedBox(height: 6),
                  Text('•  ${'lunasea.Release134Import'.tr()}'),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('lunasea.AllReleaseNotes'.tr()),
                  onPressed: () => '$_repository/releases'.openLink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _donationCarousel(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = math.min(258.0, constraints.maxWidth - 32);
        final multiPage = _availableDonations.length > 1;
        return Column(
          children: [
            SizedBox(
              height: qrSize + 104 + MediaQuery.textScalerOf(context).scale(52),
              child: PageView.builder(
                controller: _donationPages,
                itemCount: _availableDonations.length,
                onPageChanged: (page) =>
                    setState(() => _selectedDonation = page),
                itemBuilder: (context, index) => _DonationCard(
                  donation: _availableDonations[index],
                  qrSize: qrSize,
                ),
              ),
            ),
            if (multiPage)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'lunasea.PreviousDonation'.tr(),
                    onPressed: _selectedDonation > 0
                        ? () => _showDonation(_selectedDonation - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  for (final (index, donation) in _availableDonations.indexed)
                    IconButton(
                      tooltip: donation.name,
                      onPressed: () => _showDonation(index),
                      icon: Icon(
                        index == _selectedDonation
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 12,
                      ),
                    ),
                  IconButton(
                    tooltip: 'lunasea.NextDonation'.tr(),
                    onPressed:
                        _selectedDonation + 1 < _availableDonations.length
                        ? () => _showDonation(_selectedDonation + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  void _showDonation(int index) {
    _donationPages.animateToPage(
      index,
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeOut,
    );
  }
}

class _Donation {
  const _Donation(this.name, this.scheme, this.address);

  final String name;
  final String scheme;
  final String address;
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.donation, required this.qrSize});

  final _Donation donation;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
    final bitcoin = donation.scheme == 'bitcoin';
    final logoSize = qrSize * .15;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(donation.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: '${donation.scheme}:${donation.address}',
                    size: qrSize,
                    padding: EdgeInsets.all(qrSize * .09),
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'lunasea.DonationQr'.tr(
                      args: [donation.name],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      padding: EdgeInsets.all(logoSize * .1),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: bitcoin
                          ? DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF7931A),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.currency_bitcoin,
                                color: Colors.white,
                                size: logoSize * .64,
                              ),
                            )
                          : const CustomPaint(painter: _MoneroLogo()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: Text('lunasea.CopyDonationAddress'.tr()),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: donation.address));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('lunasea.DonationAddressCopied'.tr())),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneroLogo extends CustomPainter {
  const _MoneroLogo();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const circle = Rect.fromLTWH(0, 0, 100, 100);
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(circle, Paint()..color = const Color(0xFFF26822));
    canvas.drawRect(
      const Rect.fromLTRB(0, 67, 100, 100),
      Paint()..color = const Color(0xFF4C4C4C),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 72)
        ..lineTo(20, 72)
        ..lineTo(20, 27)
        ..lineTo(50, 57)
        ..lineTo(80, 27)
        ..lineTo(80, 72)
        ..lineTo(100, 72),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoneroLogo oldDelegate) => false;
}
