import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\staff_dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Add missing imports
if 'app_theme.dart' not in code:
    code = code.replace("import '../../services/api_service.dart';", 
                        "import '../../services/api_service.dart';\nimport '../../services/theme_controller.dart';\nimport '../../theme/app_theme.dart';")

# 2. Add pal to methods using it
methods_using_pal = ['_buildAppBar', '_buildHomeTab', '_buildSearchTab', '_buildApprovalsTab', '_buildOverdueTab', '_buildBottomNav']

for method in methods_using_pal:
    # Find the method start
    pattern = r'(Widget ' + method + r'\(.*?\) \{|PreferredSizeWidget ' + method + r'\(.*?\) \{)'
    def replacer(m):
        # We need to make sure we don't inject multiple times
        return m.group(1) + '\n    final pal = AppPalette.of(context);'
    
    # We remove the existing `final pal = AppPalette.of(context);` in these methods if it's there to avoid duplicates, then add it back cleanly.
    code = re.sub(pattern + r'\s*final pal = AppPalette\.of\(context\);', r'\1', code)
    code = re.sub(pattern, replacer, code)

# For Widget build(BuildContext context) in stateless widgets
def build_replacer(match):
    return match.group(1) + '\n    final pal = AppPalette.of(context);'

code = re.sub(r'(Widget build\(BuildContext context\) \{)\s*final pal = AppPalette\.of\(context\);', r'\1', code)
code = re.sub(r'(Widget build\(BuildContext context\) \{)', build_replacer, code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Imports and pal variables injected")
