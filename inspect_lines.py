from pathlib import Path
text = Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
for line in text.splitlines()[346:356]:
    print(repr(line))
