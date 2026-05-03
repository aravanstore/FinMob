import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\client_details_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# Add imports
if "theme_controller.dart" not in code:
    code = code.replace("import '../../services/api_service.dart';", 
                        "import '../../services/api_service.dart';\nimport '../../services/theme_controller.dart';\nimport '../../theme/app_theme.dart';")

# Add pal
if "final pal = AppPalette.of(context);" not in code:
    code = code.replace("final fmt = NumberFormat('#,##0.00', 'ru_RU');", 
                        "final pal = AppPalette.of(context);\n    final fmt = NumberFormat('#,##0.00', 'ru_RU');")

# Manual safe replacements for consts and colors
replacements = [
    ('backgroundColor: const Color(0xFF0F172A)', 'backgroundColor: pal.bg'),
    ('color: const Color(0xFF1E293B)', 'color: pal.card'),
    ('color: Color(0xFF1A56DB)', 'color: pal.accent'),
    
    # Text and icons
    ('const Text(', 'Text('),
    ('const TextStyle(', 'TextStyle('),
    ('const IconThemeData(', 'IconThemeData('),
    ('const Center(', 'Center('),
    ('const Icon(', 'Icon('),
    ('color: Colors.white54', 'color: pal.textSec'),
    ('color: Colors.white70', 'color: pal.textSec'),
    ('color: Colors.white38', 'color: pal.textHint'),
    ('color: Colors.white', 'color: pal.textPri'),
]

for old, new in replacements:
    code = code.replace(old, new)

# Method _infoRow uses colors? Let's check.
# _infoRow is a method. We need to pass pal or let it be accessed if it's not a method but a function.
# Wait, _infoRow is a method on the state. It needs `pal`.
code = code.replace('Widget _infoRow(IconData icon, String text) {', 'Widget _infoRow(IconData icon, String text, AppPalette pal) {')
code = code.replace("_infoRow(Icons.phone, client['phone_main'] ?? '-')", "_infoRow(Icons.phone, client['phone_main'] ?? '-', pal)")
code = code.replace("_infoRow(Icons.badge, 'ИНН: ${client['inn'] ?? '-'}')", "_infoRow(Icons.badge, 'ИНН: ${client['inn'] ?? '-'}', pal)")
code = code.replace("_infoRow(\n                        Icons.location_on, client['address_factual'] ?? '-')", "_infoRow(Icons.location_on, client['address_factual'] ?? '-', pal)")
code = code.replace("_infoRow(Icons.location_on, client['address_factual'] ?? '-')", "_infoRow(Icons.location_on, client['address_factual'] ?? '-', pal)")

# Fix _summaryItem
code = code.replace("Widget _summaryItem(String label, String value, Color color) {", "Widget _summaryItem(String label, String value, Color color, AppPalette pal) {")
code = code.replace("_summaryItem(\n                      'Всего', '${summary['total_loans']}', Colors.blue)", "_summaryItem('Всего', '${summary['total_loans']}', Colors.blue, pal)")
code = code.replace("_summaryItem('Всего', '${summary['total_loans']}', Colors.blue)", "_summaryItem('Всего', '${summary['total_loans']}', Colors.blue, pal)")
code = code.replace("_summaryItem(\n                      'Активных', '${summary['active_loans']}', Colors.green)", "_summaryItem('Активных', '${summary['active_loans']}', Colors.green, pal)")
code = code.replace("_summaryItem('Активных', '${summary['active_loans']}', Colors.green)", "_summaryItem('Активных', '${summary['active_loans']}', Colors.green, pal)")
code = code.replace("_summaryItem('Просрочено', '${summary['overdue_count']}',\n                      Colors.redAccent)", "_summaryItem('Просрочено', '${summary['overdue_count']}', Colors.redAccent, pal)")
code = code.replace("_summaryItem('Просрочено', '${summary['overdue_count']}', Colors.redAccent)", "_summaryItem('Просрочено', '${summary['overdue_count']}', Colors.redAccent, pal)")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Safely fixed client details")
