import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\staff_dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update _C class
_c_class = '''class _C {
  static const gold     = Color(0xFFF59E0B);
  static const green    = Color(0xFF10B981);
  static const red      = Color(0xFFEF4444);
  static const orange   = Color(0xFFF97316);
  static const accent   = Color(0xFF2563EB);
  static const accentLt = Color(0xFF3B82F6);
}'''
code = re.sub(r'class _C \{.*?\}', _c_class, code, flags=re.DOTALL)

# 2. Inject `final pal = AppPalette.of(context);`
def inject_pal(match):
    m = match.group(0)
    if 'final pal = AppPalette.of(context);' not in m:
        return match.group(1) + '\n    final pal = AppPalette.of(context);' + match.group(2)
    return m

code = re.sub(r'(Widget build\(BuildContext context\) \{)(.*?)(?=\n  \}|\n    return)', inject_pal, code, flags=re.DOTALL)

# Inject pal into _build methods
methods_to_inject = ['_buildHomeTab', '_buildSearchTab', '_buildApprovalsTab', '_buildOverdueTab', '_buildBottomNav']
for method in methods_to_inject:
    pattern = r'(Widget ' + method + r'\(.*?\) \{)'
    code = re.sub(pattern, r'\1\n    final pal = AppPalette.of(context);', code)

# 3. Process each line: replace _C.vars and remove "const " if line contains them
dynamic_vars = ['bg', 'surface', 'card', 'border', 'textPri', 'textSec', 'textHint']

lines = code.split('\n')
for i, line in enumerate(lines):
    has_dynamic = any(f'_C.{v}' in line for v in dynamic_vars)
    if has_dynamic:
        # Remove 'const ' on the same line
        line = re.sub(r'\bconst\s+', '', line)
        # Also, sometimes 'const ' is on the previous line. Let's check it.
        if i > 0 and 'const ' in lines[i-1] and not any(f'_C.{v}' in lines[i-1] for v in dynamic_vars):
            # Very basic check: if previous line ends with `(`, it's likely `const Widget(`
            if lines[i-1].rstrip().endswith('('):
                lines[i-1] = re.sub(r'\bconst\s+', '', lines[i-1])

    # Replace _C.var with pal.var
    for v in dynamic_vars:
        line = line.replace(f'_C.{v}', f'pal.{v}')
    
    lines[i] = line

code = '\n'.join(lines)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Done")
