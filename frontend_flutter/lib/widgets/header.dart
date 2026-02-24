import 'package:flutter/material.dart';

class DocumentHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? center;
  final String? backgroundImageUrl;
  final bool showDivider;

  const DocumentHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.center,
    this.backgroundImageUrl,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = title != null && title!.trim().isNotEmpty;

    final leftContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: leading!,
          ),
        if (hasTitle || (subtitle != null && subtitle!.isNotEmpty))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasTitle)
                Text(
                  title!.trim(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
      ],
    );

    final headerContent = Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              )
            : null,
        image:
            backgroundImageUrl != null && backgroundImageUrl!.trim().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(backgroundImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: leftContent,
          ),
          if (center != null)
            Align(
              alignment: Alignment.center,
              child: center!,
            ),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: trailing!,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return headerContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: headerContent,
      ),
    );
  }
}

class DocumentFooter extends StatelessWidget {
  final int? pageNumber;
  final int? totalPages;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const DocumentFooter({
    super.key,
    this.pageNumber,
    this.totalPages,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final footerContent = Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? const Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null ||
              (pageNumber != null && totalPages != null) ||
              trailing != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) leading!,
                if (pageNumber != null && totalPages != null)
                  Padding(
                    padding: EdgeInsets.only(top: leading != null ? 4.0 : 0.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100]!.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Page $pageNumber of $totalPages',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                if (trailing != null)
                  const SizedBox(
                    height: 4,
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          const Spacer(),
        ],
      ),
    );

    if (onTap == null) {
      return footerContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: footerContent,
      ),
    );
  }
}
