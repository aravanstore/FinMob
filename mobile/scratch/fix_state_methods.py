import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\client_details_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# Revert signatures
code = code.replace("Widget _infoRow(IconData icon, String text, AppPalette pal) {", "Widget _infoRow(IconData icon, String text) {")
code = code.replace("Widget _summaryItem(String label, String value, Color color, AppPalette pal) {", "Widget _summaryItem(String label, String value, Color color) {")

# Revert calls
code = re.sub(r"_infoRow\((.*?), pal\)", r"_infoRow(\1)", code)
code = re.sub(r"_summaryItem\((.*?), pal\)", r"_summaryItem(\1)", code)

# Inject pal into these methods
methods = ['_infoRow', '_summaryItem', '_loanTile']

for m in methods:
    pattern = r'(Widget ' + m + r'\(.*?\) \{)'
    def replacer(match):
        return match.group(1) + '\n    final pal = AppPalette.of(context);'
    
    # Clean up existing pal if any to avoid duplicates
    code = re.sub(pattern + r'\s*final pal = AppPalette\.of\(context\);', r'\1', code)
    code = re.sub(pattern, replacer, code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Fixed state methods")
