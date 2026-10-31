import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/page.dart';
import '../widgets/pc_card.dart';

/// Settings: the PC this phone is paired with.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _forget(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Cozy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Forget this PC?', style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          "You'll need to scan a new code on your PC to link them again.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget', style: TextStyle(color: Cozy.danger)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await Link.forget();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      title: 'Settings',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text('Your PC', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19)),
          const SizedBox(height: 10),
          StreamBuilder<LinkState>(
            stream: Link.states,
            initialData: Link.last,
            builder: (_, snap) => PcCard(link: snap.data!),
          ),
          const SizedBox(height: 30),
          BubbleButton(
            label: 'Forget this PC',
            color: Cozy.card,
            ledge: Cozy.cardShadow,
            textColor: Cozy.danger,
            height: 58,
            onPressed: () => _forget(context),
          ),
          const SizedBox(height: 18),
          Center(child: Text('Island Link 0.2.2 · made with a leaf', style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
