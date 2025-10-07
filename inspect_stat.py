from pathlib import Path
for idx,line in enumerate(Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8').splitlines(),1):
    if "_StatItem" in line:
        print(idx, repr(line))
