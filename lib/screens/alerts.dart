import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// Phone notifications as Island bubbles: Android's permission plus an on/off switch.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool? _access;
  bool _on = true;
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: _load); // back from Android's settings

  @override
  void initState() {
    super.initState();
    _life;
    _load();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final access = await Link.alertsAccess();
    final on = await Link.alertsOn();
    if (mounted) {
      setState(() {
        _access = access;
        _on = on;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CozyPage(
      title: 'Alerts',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 10),
          const Icon(Icons.notifications_active_rounded, size: 72, color: Color(0xFFE9C46A)),
          const SizedBox(height: 12),
          Text('Phone alerts on your PC', textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 8),
          const Hint('New notifications show up as Island bubbles. Ongoing ones like music are left out.'),
          const SizedBox(height: 24),
          if (_access == false) ...[
            BubbleButton(label: 'Allow in Android', onPressed: Link.openAlertsAccess),
            const SizedBox(height: 12),
            const Hint('Find Island Link in the list and turn it on, then come back.'),
          ],
          if (_access == true)
            CozyCard(
              padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
              child: Row(
                children: [
                  Expanded(child: Text('Send to my PC', style: text.titleMedium)),
                  Switch(
                    value: _on,
                    activeTrackColor: Cozy.leaf,
                    onChanged: (v) {
                      Link.setAlertsOn(v);
                      setState(() => _on = v);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
