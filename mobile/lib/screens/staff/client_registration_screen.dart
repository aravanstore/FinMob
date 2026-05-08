import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'client_registration_screen_old.dart';
import 'client_registration_screen_new.dart';

class ClientRegistrationScreen extends StatelessWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;
  const ClientRegistrationScreen({super.key, this.clientId, this.initialData});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final bool isUpdate = clientId != null;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        title: Text(isUpdate ? 'Обновление данных' : 'Регистрация', style: TextStyle(color: pal.textPri)),
        iconTheme: IconThemeData(color: pal.textPri),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOptionCard(
                context,
                title: 'СТАРЫЙ ПАСПОРТ',
                subtitle: 'ID, AN, IK серии (BAC)',
                icon: Icons.badge_outlined,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClientRegistrationScreenOld(clientId: clientId, initialData: initialData)),
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                context,
                title: 'НОВЫЙ ПАСПОРТ',
                subtitle: 'Выдан в 2024+ (PACE)',
                icon: Icons.contact_emergency_outlined,
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClientRegistrationScreenNew(clientId: clientId, initialData: initialData)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.darken(0.2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final darkenedHsv = hsv.withValue((hsv.value - amount).clamp(0.0, 1.0));
    return darkenedHsv.toColor();
  }
}