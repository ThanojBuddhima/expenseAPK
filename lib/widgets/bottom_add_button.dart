import 'package:flutter/material.dart';

/// Full-width primary add action pinned to the bottom of manage screens.
class BottomAddButtonBar extends StatelessWidget {
  const BottomAddButtonBar({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

/// List content with a bottom add button bar.
class ManageListScaffold extends StatelessWidget {
  const ManageListScaffold({
    super.key,
    required this.addLabel,
    required this.onAdd,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: children,
          ),
        ),
        BottomAddButtonBar(label: addLabel, onPressed: onAdd),
      ],
    );
  }
}
