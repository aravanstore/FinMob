import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\client_details_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacements = {
    'const Color(0xFF0F172A)': 'pal.bg',
    'Color(0xFF0F172A)': 'pal.bg',
    'const Color(0xFF1E293B)': 'pal.card',
    'Color(0xFF1E293B)': 'pal.card',
    'Colors.white': 'pal.textPri',
    'Colors.white54': 'pal.textSec',
    'Colors.white70': 'pal.textSec',
    'Color(0xFF1A56DB)': 'pal.accent',
    'const Color(0xFF1A56DB)': 'pal.accent',
}

for old, new in replacements.items():
    code = code.replace(old, new)

# And now since we replaced `const Color...` with `pal.something`, we need to remove `const` from `const TextStyle(...)` and `const IconThemeData(...)` etc.
code = re.sub(r'\bconst\s+(TextStyle|IconThemeData|Center)\(.*?(pal\.)', r'\1(\2', code)
code = re.sub(r'\bconst\s+(Text)\(.*?(pal\.)', r'\1(\2', code)
code = re.sub(r'\bconst\s+(BoxDecoration)\(.*?(pal\.)', r'\1(\2', code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Fixed client details")
