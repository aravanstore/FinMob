import re
import sys

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\staff_dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update _C class
new_c_class = '''class _C {
  static const gold     = Color(0xFFF59E0B);
  static const green    = Color(0xFF10B981);
  static const red      = Color(0xFFEF4444);
  static const orange   = Color(0xFFF97316);
  static const accent   = Color(0xFF2563EB);
  static const accentLt = Color(0xFF3B82F6);
}'''
code = re.sub(r'class _C \{.*?\}', new_c_class, code, flags=re.DOTALL | re.MULTILINE)

# 2. Add `final pal = AppPalette.of(context);` to build methods of widgets that don't have it
def build_replacer(match):
    m = match.group(0)
    if 'final pal = AppPalette.of(context);' not in m:
        # inject after "{"
        return match.group(1) + '\n    final pal = AppPalette.of(context);' + match.group(2)
    return m

code = re.sub(r'(Widget build\(BuildContext context\) \{)(.*?)(?=\n  \}|\n    return)', build_replacer, code, flags=re.DOTALL)

# 3. Replace theme colors
replacements = {
    '_C.bg': 'pal.bg',
    '_C.surface': 'pal.surface',
    '_C.card': 'pal.card',
    '_C.border': 'pal.border',
    '_C.textPri': 'pal.textPri',
    '_C.textSec': 'pal.textSec',
    '_C.textHint': 'pal.textHint',
}

for old, new in replacements.items():
    code = code.replace(old, new)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Done")
