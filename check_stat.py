with open('frontend/lib/features/profile/presentation/profile_screen.dart','r',encoding='utf-8') as f:
    for line in f:
        if '_StatItem' in line:
            print(repr(line))
