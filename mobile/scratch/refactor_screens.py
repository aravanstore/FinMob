import re
import sys

def process_file(filepath):
    print(f"Processing {filepath}")
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

    # 2. Add imports
    if 'app_theme.dart' not in code:
        code = code.replace("import '../../services/api_service.dart';", 
                            "import '../../services/api_service.dart';\nimport '../../services/theme_controller.dart';\nimport '../../theme/app_theme.dart';")
        # In case api_service wasn't imported (some screens might not use it directly but usually they do)
        if "import '../../services/api_service.dart';" not in code:
             code = code.replace("import 'package:flutter/material.dart';", 
                                "import 'package:flutter/material.dart';\nimport '../../theme/app_theme.dart';")

    # 3. Inject `final pal = AppPalette.of(context);` into ALL widget build methods
    def build_replacer(match):
        m = match.group(0)
        if 'final pal = AppPalette.of(context);' not in m:
            return match.group(1) + '\n    final pal = AppPalette.of(context);' + match.group(2)
        return m
    code = re.sub(r'(Widget build\(BuildContext context\) \{)(.*?)(?=\n  \}|\n    return)', build_replacer, code, flags=re.DOTALL)

    # Also for any helper method that returns Widget and takes BuildContext
    def widget_method_replacer(match):
        m = match.group(0)
        if 'final pal = AppPalette.of(context);' not in m:
            return match.group(1) + '\n    final pal = AppPalette.of(context);'
        return m
    code = re.sub(r'(Widget _build.*?\(.*?BuildContext context.*?\) \{)', widget_method_replacer, code)

    # Clean up duplicate injections
    code = re.sub(r'(Widget build\(BuildContext context\) \{)\s*final pal = AppPalette\.of\(context\);', r'\1', code)
    code = re.sub(r'(Widget build\(BuildContext context\) \{)', r'\1\n    final pal = AppPalette.of(context);', code)

    # 4. Process lines to replace _C.vars and remove const
    dynamic_vars = ['bg', 'surface', 'card', 'border', 'textPri', 'textSec', 'textHint']
    lines = code.split('\n')
    for i, line in enumerate(lines):
        has_dynamic = any(f'_C.{v}' in line for v in dynamic_vars)
        if has_dynamic:
            line = re.sub(r'\bconst\s+', '', line)
            if i > 0 and 'const ' in lines[i-1] and not any(f'_C.{v}' in lines[i-1] for v in dynamic_vars):
                if lines[i-1].rstrip().endswith('('):
                    lines[i-1] = re.sub(r'\bconst\s+', '', lines[i-1])

        for v in dynamic_vars:
            line = line.replace(f'_C.{v}', f'pal.{v}')
        lines[i] = line

    code = '\n'.join(lines)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(code)

files = [
    r'c:\Projects\FinMob\mobile\lib\screens\staff\client_details_screen.dart',
    r'c:\Projects\FinMob\mobile\lib\screens\staff\loan_details_screen.dart',
    r'c:\Projects\FinMob\mobile\lib\screens\staff\share_details_screen.dart'
]

for f in files:
    process_file(f)

print("Done all screens")
