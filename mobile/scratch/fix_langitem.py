import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\staff_dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

# Fix _langItem parameter
code = code.replace("PopupMenuItem<Locale> _langItem(String code, String label, Locale locale) {", 
                    "PopupMenuItem<Locale> _langItem(String code, String label, Locale locale, AppPalette pal) {")

# Pass pal to _langItem calls
code = code.replace("_langItem('RU', 'Русский',   const Locale('ru'))", 
                    "_langItem('RU', 'Русский',   const Locale('ru'), pal)")
code = code.replace("_langItem('KY', 'Кыргызча', const Locale('ky'))", 
                    "_langItem('KY', 'Кыргызча', const Locale('ky'), pal)")
code = code.replace("_langItem('EN', 'English',   const Locale('en'))", 
                    "_langItem('EN', 'English',   const Locale('en'), pal)")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(code)

print("Fixed _langItem")
