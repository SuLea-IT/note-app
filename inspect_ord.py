from pathlib import Path
line=Path('frontend/lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8').splitlines()[354]
print(line)
print([ord(c) for c in line])
