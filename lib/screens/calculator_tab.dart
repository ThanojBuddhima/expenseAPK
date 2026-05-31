import 'package:flutter/material.dart';

import '../app_theme.dart';

const Color _kCalcOp = AppColors.primaryDeep;

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  String _display = '0';
  String _expression = '0';
  String _operation = '';
  double _previousValue = 0;
  bool _waitingForOperand = false;
  bool _justEvaluated = false;

  void _updateExpression() {
    if (_operation.isEmpty) {
      _expression = _display;
      return;
    }
    if (_waitingForOperand) {
      _expression = '${_formatResult(_previousValue)}$_operation';
      return;
    }
    _expression =
        '${_formatResult(_previousValue)}$_operation$_display';
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_justEvaluated) {
        _display = number;
        _operation = '';
        _previousValue = 0;
        _waitingForOperand = false;
        _justEvaluated = false;
      } else if (_waitingForOperand) {
        _display = number;
        _waitingForOperand = false;
      } else if (_display == '0') {
        _display = number;
      } else {
        _display += number;
      }
      _updateExpression();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_justEvaluated) {
        _display = '0.';
        _operation = '';
        _previousValue = 0;
        _waitingForOperand = false;
        _justEvaluated = false;
      } else if (_waitingForOperand) {
        _display = '0.';
        _waitingForOperand = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
      _updateExpression();
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '0';
      _operation = '';
      _previousValue = 0;
      _waitingForOperand = false;
      _justEvaluated = false;
    });
  }

  void _onBackspace() {
    setState(() {
      _justEvaluated = false;

      if (_waitingForOperand) {
        _operation = '';
        _waitingForOperand = false;
        _display = _formatResult(_previousValue);
        _updateExpression();
        return;
      }

      if (_display.length <= 1 ||
          (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
      _updateExpression();
    });
  }

  void _onPercent() {
    setState(() {
      final value = double.tryParse(_display) ?? 0;
      _display = _formatResult(value / 100);
      _waitingForOperand = false;
      _justEvaluated = false;
      _updateExpression();
    });
  }

  void _onOperation(String operation) {
    setState(() {
      final current = double.tryParse(_display) ?? 0;

      if (_justEvaluated) {
        _previousValue = current;
        _justEvaluated = false;
      } else if (_operation.isNotEmpty && !_waitingForOperand) {
        _previousValue = _calculate(_previousValue, current, _operation);
        _display = _formatResult(_previousValue);
      } else {
        _previousValue = current;
      }

      _operation = operation;
      _waitingForOperand = true;
      _updateExpression();
    });
  }

  void _onEquals() {
    if (_operation.isEmpty || _waitingForOperand) {
      return;
    }
    setState(() {
      final current = double.tryParse(_display) ?? 0;
      final left = _formatResult(_previousValue);
      final result = _calculate(_previousValue, current, _operation);
      _expression = '$left$_operation$_display=${_formatResult(result)}';
      _display = _formatResult(result);
      _operation = '';
      _previousValue = 0;
      _waitingForOperand = false;
      _justEvaluated = true;
    });
  }

  double _calculate(double left, double right, String operation) {
    switch (operation) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '×':
        return left * right;
      case '÷':
        return right == 0 ? 0 : left / right;
      default:
        return right;
    }
  }

  String _formatResult(double value) {
    if (value.isInfinite || value.isNaN) {
      return 'Error';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, AppTheme.screenTopPadding, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Spacer(),
                  if (_justEvaluated) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _expression,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _display,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ] else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _expression,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                const cols = 4;
                final buttonSize =
                    (constraints.maxWidth - spacing * (cols - 1)) / cols;
                final gridHeight = buttonSize * 5 + spacing * 4;

                Widget sizedButton(Widget button) => SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: button,
                    );

                Widget keypadRow(List<Widget> buttons) => Row(
                      children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0) SizedBox(width: spacing),
                          sizedButton(buttons[i]),
                        ],
                      ],
                    );

                return SizedBox(
                  height: gridHeight,
                  child: Column(
                    children: [
                      keypadRow([
                        _CalculatorButton(
                          palette.textSecondary,
                          _onClear,
                          label: 'C',
                          isAction: true,
                        ),
                        _CalculatorButton(_kCalcOp, () => _onOperation('÷'), label: '÷', isOperation: true),
                        _CalculatorButton(_kCalcOp, () => _onOperation('×'), label: '×', isOperation: true),
                        _CalculatorButton(
                          palette.textSecondary,
                          _onBackspace,
                          icon: Icons.backspace_outlined,
                          isAction: true,
                        ),
                      ]),
                      SizedBox(height: spacing),
                      keypadRow([
                        _CalculatorButton(palette.input, () => _onNumberPressed('7'), label: '7', numberStyle: true),
                        _CalculatorButton(palette.input, () => _onNumberPressed('8'), label: '8', numberStyle: true),
                        _CalculatorButton(palette.input, () => _onNumberPressed('9'), label: '9', numberStyle: true),
                        _CalculatorButton(_kCalcOp, () => _onOperation('-'), label: '-', isOperation: true),
                      ]),
                      SizedBox(height: spacing),
                      keypadRow([
                        _CalculatorButton(palette.input, () => _onNumberPressed('4'), label: '4', numberStyle: true),
                        _CalculatorButton(palette.input, () => _onNumberPressed('5'), label: '5', numberStyle: true),
                        _CalculatorButton(palette.input, () => _onNumberPressed('6'), label: '6', numberStyle: true),
                        _CalculatorButton(_kCalcOp, () => _onOperation('+'), label: '+', isOperation: true),
                      ]),
                      SizedBox(height: spacing),
                      SizedBox(
                        height: buttonSize * 2 + spacing,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: buttonSize * 3 + spacing * 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        sizedButton(_CalculatorButton(
                                            palette.input, () => _onNumberPressed('1'), label: '1', numberStyle: true)),
                                        SizedBox(width: spacing),
                                        sizedButton(_CalculatorButton(
                                            palette.input, () => _onNumberPressed('2'), label: '2', numberStyle: true)),
                                        SizedBox(width: spacing),
                                        sizedButton(_CalculatorButton(
                                            palette.input, () => _onNumberPressed('3'), label: '3', numberStyle: true)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        sizedButton(_CalculatorButton(
                                            palette.textSecondary, _onPercent, label: '%', isAction: true)),
                                        SizedBox(width: spacing),
                                        sizedButton(_CalculatorButton(
                                            palette.input, () => _onNumberPressed('0'), label: '0', numberStyle: true)),
                                        SizedBox(width: spacing),
                                        sizedButton(_CalculatorButton(
                                            palette.input, _onDecimalPressed, label: '.', numberStyle: true)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: spacing),
                            SizedBox(
                              width: buttonSize,
                              child: _CalculatorButton(
                                AppColors.incomeTint,
                                _onEquals,
                                label: '=',
                                isOperation: true,
                                fillCell: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculatorButton extends StatelessWidget {
  const _CalculatorButton(
    this.bgColor,
    this.onPressed, {
    this.label,
    this.icon,
    this.isOperation = false,
    this.isAction = false,
    this.numberStyle = false,
    this.fillCell = false,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final Color bgColor;
  final VoidCallback onPressed;
  final bool isOperation;
  final bool isAction;
  final bool numberStyle;
  final bool fillCell;

  @override
  Widget build(BuildContext context) {
    final textColor = isOperation || isAction
        ? Colors.white
        : (numberStyle
            ? context.palette.textPrimary
            : Theme.of(context).colorScheme.onSurface);

    final content = Center(
      child: icon != null
          ? Icon(icon, color: textColor, size: 22)
          : Text(
              label!,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    if (fillCell) {
      return Material(
        color: bgColor,
        shape: const StadiumBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox.expand(child: content),
        ),
      );
    }

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: AspectRatio(
          aspectRatio: 1,
          child: content,
        ),
      ),
    );
  }
}
