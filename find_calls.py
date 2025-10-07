from pathlib import Path
text = Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
for idx,line in enumerate(text.splitlines(),1):
    if '_languageLabel' in line or '_themeLabel' in line:
        print(idx, line)
