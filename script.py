from pathlib import Path
text = Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
import re
for m in re.finditer(r'def _languageLabel', text):
    pass
print('done')
