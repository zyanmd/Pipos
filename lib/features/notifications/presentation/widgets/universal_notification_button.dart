import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/universal_notification_service.dart';
import '../universal_notification_modal.dart';

/// Universal Notification Logo/Button ("Logo Notif Umum Universal")
/// Displays a bell icon with a real-time unread badge combining:
/// - Anime Comments (likes & replies)
/// - General Community Chat (mentions & replies)
class UniversalNotificationButton extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? customOnTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const UniversalNotificationButton({
    super.key,
    this.size = 38,
    this.padding,
    this.customOnTap,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
      child: ValueListenableBuilder<int>(
        valueListenable: UniversalNotificationService.instance.totalUnreadNotifier,
        builder: (context, totalUnread, _) {
          return Tooltip(
            message: totalUnread > 0 ? 'Notifikasi ($totalUnread baru)' : 'Notifikasi',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                if (customOnTap != null) {
                  customOnTap!();
                } else {
                  UniversalNotificationModal.show(context);
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: backgroundColor ??
                          (isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7)),
                      border: Border.all(
                        color: borderColor ??
                            (isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB)),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      totalUnread > 0 ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                      size: size * 0.48,
                      color: iconColor ?? (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF16161A) : Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

