from pathlib import Path
text = Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
for idx,line in enumerate(text.splitlines(),1):
    if 'StatItem' in line:
        print(idx, repr(line))
