import re

files = [
    r'c:\Projects\FinMob\mobile\lib\screens\staff\client_details_screen.dart',
    r'c:\Projects\FinMob\mobile\lib\screens\staff\loan_details_screen.dart',
    r'c:\Projects\FinMob\mobile\lib\screens\staff\share_details_screen.dart'
]

def fix_build_methods(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        code = f.read()

    def method_replacer(match):
        m = match.group(0)
        if 'final pal = AppPalette.of(context);' not in m:
            return match.group(1) + '\n    final pal = AppPalette.of(context);'
        return m

    code = re.sub(r'(Widget _build.*?\(.*?\) \{)', method_replacer, code)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(code)

for f in files:
    fix_build_methods(f)

print("Fixed methods")
