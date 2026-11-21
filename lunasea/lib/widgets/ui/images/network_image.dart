import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

class LunaNetworkImage extends ClipRRect {
  LunaNetworkImage({
    Key? key,
    required BuildContext context,
    required double height,
    required double width,
    String? url,
    IconData? placeholderIcon,
    Map? headers,
    bool? monitored,
  }) : super(
          key: key,
          child: SizedBox(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: height,
                  width: width,
                  child: Center(
                    child: placeholderIcon != null
                        ? Icon(
                            placeholderIcon,
                            color: LunaColours.accent,
                            size: width * 0.40,
                          )
                        : null,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.circular(LunaUI.BORDER_RADIUS),
                    border: LunaUI.shouldUseBorder
                        ? Border.all(color: LunaColours.white10)
                        : null,
                  ),
                ),
                if (url?.isNotEmpty ?? false)
                  _RetryMissingPoster(
                    monitored: monitored,
                    url: url!,
                    builder: (key, failed) => FadeInImage(
                      key: key,
                      height: height,
                      width: width,
                      fadeInDuration: const Duration(
                        milliseconds: LunaUI.ANIMATION_SPEED_IMAGES,
                      ),
                      fadeOutDuration: const Duration(milliseconds: 1),
                      placeholder: MemoryImage(kTransparentImage),
                      fit: BoxFit.cover,
                      image: LunaNetworkImageProvider(
                        url: url,
                        headers: headers?.cast<String, String>(),
                      ).imageProvider,
                      imageErrorBuilder: (context, error, stack) {
                        failed();
                        return SizedBox(height: height, width: width);
                      },
                    ),
                  ),
              ],
            ),
            height: height,
            width: width,
          ),
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(LunaUI.BORDER_RADIUS),
        );
}

class _RetryMissingPoster extends StatefulWidget {
  final bool? monitored;
  final String url;
  final Widget Function(Key, VoidCallback) builder;

  const _RetryMissingPoster({
    required this.monitored,
    required this.url,
    required this.builder,
  });

  @override
  State<_RetryMissingPoster> createState() => _RetryMissingPosterState();
}

class _RetryMissingPosterState extends State<_RetryMissingPoster> {
  bool failed = false;
  int attempt = 0;

  @override
  void didUpdateWidget(_RetryMissingPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      failed = false;
    } else if (failed && widget.monitored != oldWidget.monitored) {
      attempt++;
      failed = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(ValueKey(attempt), () => failed = true);
}
