import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/extension.dart';
import 'package:kazumi/utils/utils.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatefulWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.onTap,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final VoidCallback? onTap;

  @override
  State<BangumiCardV> createState() => _BangumiCardVState();
}

class _BangumiCardVState extends State<BangumiCardV> {
  int? _fixedMemCacheWidth;
  int? _fixedMemCacheHeight;

  @override
  void didUpdateWidget(covariant BangumiCardV oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bangumiItem.id != widget.bangumiItem.id ||
        oldWidget.bangumiItem.images['large'] !=
            widget.bangumiItem.images['large']) {
      _fixedMemCacheWidth = null;
      _fixedMemCacheHeight = null;
    }
  }

  void _initFixedMemCacheSize(
    BuildContext context,
    double width,
    double height,
  ) {
    if (_fixedMemCacheWidth != null || _fixedMemCacheHeight != null) {
      return;
    }
    final aspectRatio = (width / height).toDouble();
    if (aspectRatio > 1) {
      _fixedMemCacheHeight = height.cacheSize(context);
    } else if (aspectRatio < 1) {
      _fixedMemCacheWidth = width.cacheSize(context);
    } else {
      _fixedMemCacheWidth = width.cacheSize(context);
      _fixedMemCacheHeight = height.cacheSize(context);
    }
    if (_fixedMemCacheWidth == null && _fixedMemCacheHeight == null) {
      _fixedMemCacheWidth = width.toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.canTap;
    final onTap = widget.onTap;
    final bangumiItem = widget.bangumiItem;
    final enableHero = widget.enableHero;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          onTap: () {
            if (!canTap) {
              KazumiDialog.showToast(
                message: '编辑模式',
              );
              return;
            }
            if (onTap != null) {
              onTap();
              return;
            }
            Modular.to.pushNamed('/info/', arguments: bangumiItem);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: StyleString.bangumiCoverAspectRatio,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  _initFixedMemCacheSize(context, maxWidth, maxHeight);
                  return enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          tag: bangumiItem.id,
                          child: NetworkImgLayer(
                            src: bangumiItem.images['large'] ?? '',
                            width: maxWidth,
                            height: maxHeight,
                            fixedMemCacheWidth: _fixedMemCacheWidth,
                            fixedMemCacheHeight: _fixedMemCacheHeight,
                          ),
                        )
                      : NetworkImgLayer(
                          src: bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                          fixedMemCacheWidth: _fixedMemCacheWidth,
                          fixedMemCacheHeight: _fixedMemCacheHeight,
                        );
                }),
              ),
              BangumiContent(bangumiItem: bangumiItem)
            ],
          ),
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);

    final int maxTextLines = Utils.isDesktop()
        ? 3
        : (Utils.isTablet() &&
                MediaQuery.of(context).orientation == Orientation.landscape)
            ? 3
            : 2;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          bangumiItem.nameCn,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: ts.clamp(maxScaleFactor: 1.1),
          maxLines: maxTextLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// 视频卡片 - 紧凑网格布局（标题覆盖在封面底部）
class BangumiCardCompact extends StatefulWidget {
  const BangumiCardCompact({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.onTap,
    this.titleMaxLines = 2,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final VoidCallback? onTap;
  final int titleMaxLines;

  @override
  State<BangumiCardCompact> createState() => _BangumiCardCompactState();
}

class _BangumiCardCompactState extends State<BangumiCardCompact> {
  int? _fixedMemCacheWidth;
  int? _fixedMemCacheHeight;

  @override
  void didUpdateWidget(covariant BangumiCardCompact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bangumiItem.id != widget.bangumiItem.id ||
        oldWidget.bangumiItem.images['large'] !=
            widget.bangumiItem.images['large']) {
      _fixedMemCacheWidth = null;
      _fixedMemCacheHeight = null;
    }
  }

  void _initFixedMemCacheSize(
    BuildContext context,
    double width,
    double height,
  ) {
    if (_fixedMemCacheWidth != null || _fixedMemCacheHeight != null) {
      return;
    }
    final aspectRatio = (width / height).toDouble();
    if (aspectRatio > 1) {
      _fixedMemCacheHeight = height.cacheSize(context);
    } else if (aspectRatio < 1) {
      _fixedMemCacheWidth = width.cacheSize(context);
    } else {
      _fixedMemCacheWidth = width.cacheSize(context);
      _fixedMemCacheHeight = height.cacheSize(context);
    }
    if (_fixedMemCacheWidth == null && _fixedMemCacheHeight == null) {
      _fixedMemCacheWidth = width.toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.canTap;
    final onTap = widget.onTap;
    final bangumiItem = widget.bangumiItem;
    final enableHero = widget.enableHero;
    final titleText =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      height: 1.2,
      shadows: const [
        Shadow(
          color: Color(0xAA000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          if (!canTap) {
            KazumiDialog.showToast(message: '编辑模式');
            return;
          }
          if (onTap != null) {
            onTap();
            return;
          }
          Modular.to.pushNamed('/info/', arguments: bangumiItem);
        },
        child: AspectRatio(
          aspectRatio: StyleString.bangumiCoverAspectRatio,
          child: LayoutBuilder(
            builder: (context, boxConstraints) {
              final double maxWidth = boxConstraints.maxWidth;
              final double maxHeight = boxConstraints.maxHeight;
              _initFixedMemCacheSize(context, maxWidth, maxHeight);

              final image = NetworkImgLayer(
                src: bangumiItem.images['large'] ?? '',
                width: maxWidth,
                height: maxHeight,
                fixedMemCacheWidth: _fixedMemCacheWidth,
                fixedMemCacheHeight: _fixedMemCacheHeight,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          tag: bangumiItem.id,
                          child: image,
                        )
                      : image,
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xBF000000),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      titleText,
                      maxLines: widget.titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// 视频卡片 - 列表布局（左图右文）
class BangumiCardList extends StatefulWidget {
  const BangumiCardList({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.onTap,
    this.showRating = true,
    this.itemHeight = singleLineHeight,
  });

  static const double singleLineHeight = 50;

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final VoidCallback? onTap;
  final bool showRating;
  final double itemHeight;

  @override
  State<BangumiCardList> createState() => _BangumiCardListState();
}

class _BangumiCardListState extends State<BangumiCardList> {
  int? _fixedMemCacheWidth;
  int? _fixedMemCacheHeight;

  String _extractEpisodeLabel(BangumiItem item) {
    final source = item.info.trim();
    if (source.isEmpty) return '--';
    final patterns = <RegExp>[
      RegExp(r'(\d+)\s*(?:话|集)'),
      RegExp(r'(?:全|共)\s*(\d+)\s*(?:话|集)'),
      RegExp(r'(\d+)\s*(?:episodes?|eps?)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      if (match != null && match.groupCount >= 1) {
        final value = match.group(1);
        if (value != null && value.isNotEmpty) {
          return '$value集';
        }
      }
    }
    return '--';
  }

  @override
  void didUpdateWidget(covariant BangumiCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bangumiItem.id != widget.bangumiItem.id ||
        oldWidget.bangumiItem.images['large'] !=
            widget.bangumiItem.images['large']) {
      _fixedMemCacheWidth = null;
      _fixedMemCacheHeight = null;
    }
  }

  void _initFixedMemCacheSize(
    BuildContext context,
    double width,
    double height,
  ) {
    if (_fixedMemCacheWidth != null || _fixedMemCacheHeight != null) {
      return;
    }
    final aspectRatio = (width / height).toDouble();
    if (aspectRatio > 1) {
      _fixedMemCacheHeight = height.cacheSize(context);
    } else if (aspectRatio < 1) {
      _fixedMemCacheWidth = width.cacheSize(context);
    } else {
      _fixedMemCacheWidth = width.cacheSize(context);
      _fixedMemCacheHeight = height.cacheSize(context);
    }
    if (_fixedMemCacheWidth == null && _fixedMemCacheHeight == null) {
      _fixedMemCacheWidth = width.toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bangumiItem = widget.bangumiItem;
    final double itemHeight = widget.itemHeight;
    final double imageWidth = itemHeight * StyleString.bangumiCoverAspectRatio;
    final title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    final episodeLabel = _extractEpisodeLabel(bangumiItem);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleString.imgRadius.x),
      ),
      child: InkWell(
        onTap: () {
          if (!widget.canTap) {
            KazumiDialog.showToast(message: '编辑模式');
            return;
          }
          if (widget.onTap != null) {
            widget.onTap!();
            return;
          }
          Modular.to.pushNamed('/info/', arguments: bangumiItem);
        },
        child: SizedBox(
          height: itemHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: imageWidth,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _initFixedMemCacheSize(
                      context,
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final image = NetworkImgLayer(
                      src: bangumiItem.images['large'] ?? '',
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      fixedMemCacheWidth: _fixedMemCacheWidth,
                      fixedMemCacheHeight: _fixedMemCacheHeight,
                    );
                    if (!widget.enableHero) {
                      return image;
                    }
                    return Hero(
                      transitionOnUserGestures: true,
                      tag: bangumiItem.id,
                      child: image,
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 54,
                        child: Text(
                          episodeLabel,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
