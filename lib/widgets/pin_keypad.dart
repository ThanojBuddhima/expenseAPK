import 'package:flutter/material.dart';

import '../app_theme.dart';

const int kPinLength = 4;

class PinDotsRow extends StatelessWidget {
  const PinDotsRow({
    super.key,
    required this.filledCount,
    this.length = kPinLength,
    this.shake = false,
  });

  final int filledCount;
  final int length;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final filled = index < filledCount;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 14,
            width: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? primary : Colors.transparent,
              border: Border.all(
                color: filled ? primary : palette.textSecondary,
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onContinue,
    this.continueEnabled = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onContinue;
  final bool continueEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const spacing = 12.0;
    const cols = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;

        Widget keyButton({
          required Widget child,
          required VoidCallback? onTap,
          Color? background,
        }) {
          return SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Material(
              color: background ?? palette.input,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(child: child),
              ),
            ),
          );
        }

        Widget digitKey(String digit) => keyButton(
              onTap: () => onDigit(digit),
              child: Text(
                digit,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
              ),
            );

        Widget row(List<Widget> keys) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < keys.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  keys[i],
                ],
              ],
            );

        final continueKey = onContinue != null
            ? keyButton(
                onTap: continueEnabled ? onContinue : null,
                background: continueEnabled
                    ? Theme.of(context).colorScheme.primary
                    : palette.input,
                child: Icon(
                  Icons.check_rounded,
                  color: continueEnabled
                      ? Colors.white
                      : palette.textSecondary.withValues(alpha: 0.4),
                  size: 28,
                ),
              )
            : SizedBox(width: buttonSize, height: buttonSize);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([digitKey('1'), digitKey('2'), digitKey('3')]),
            SizedBox(height: spacing),
            row([digitKey('4'), digitKey('5'), digitKey('6')]),
            SizedBox(height: spacing),
            row([digitKey('7'), digitKey('8'), digitKey('9')]),
            SizedBox(height: spacing),
            row([
              continueKey,
              digitKey('0'),
              keyButton(
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_outlined,
                  color: palette.textSecondary,
                  size: 22,
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}
