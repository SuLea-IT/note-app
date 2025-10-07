import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'English': 'English',
      'Keep it up! Your consistency is visible.': 'Keep it up! Your consistency is visible.',
      '朋友': 'Friend',
      '已退出登录': 'Signed out',
      '加载日记模板失败': 'Failed to load diary templates',
      '日记创建成功': 'Diary created successfully',
      '创建日记失败': 'Failed to create diary',
      '即将为你打开新的体验': 'New experience coming soon',
      '加载失败': 'Failed to load',
      '今日待办': 'Tasks today',
      '已逾期': 'Overdue',
      '本周计划': 'This week',
      '今日完成': 'Completed today',
      '首页': 'Home',
      '我的': 'Profile',
      'MIME 类型（选填）': 'MIME type (optional)',
      '不设置': 'None',
      '个人中心建设中': 'Profile section under construction',
      '主题模式': 'Theme mode',
      '主题颜色': 'Theme color',
      '今日习惯': 'Today\'s habits',
      '今日还没有任务，立即为自己制定一个目标吧': 'No tasks yet. Set a goal for today!',
      '任务已删除': 'Task deleted',
      '任务详情': 'Task details',
      '优先级：': 'Priority:',
      '保存': 'Save',
      '保存习惯': 'Save habit',
      '保持良好的安全习惯': 'Keep good security habits',
      '保留原始音频': 'Keep original audio',
      '修改密码': 'Change password',
      '偏好语言': 'Preferred language',
      '允许分享': 'Allow sharing',
      '元信息': 'Metadata',
      '全天': 'All day',
      '关闭后可重新录制并替换': 'Turn off to re-record and replace',
      '写日记': 'Write diary',
      '分享链接': 'Share link',
      '创建第一条日记或笔记，主页就会充实起来。': 'Create your first diary or note to fill up the home page.',
      '创建账号': 'Create account',
      '删除': 'Delete',
      '删除任务': 'Delete task',
      '删除失败，请稍后重试': 'Delete failed, please try again later',
      '删除日记': 'Delete diary',
      '删除笔记': 'Delete note',
      '删除语音笔记': 'Delete voice note',
      '到期前提醒': 'Remind before due date',
      '刷新试试': 'Refresh and try again',
      '功能即将上线，敬请期待': 'Coming soon',
      '双重验证': 'Two-factor authentication',
      '取消': 'Cancel',
      '可使用标签快速分类，如“工作”“个人”': 'Use tags like “Work” or “Personal” for quick grouping.',
      '可在此拓展资料、统计面板、主题设置等功能。': 'Expand profile details, analytics, theme settings, and more here.',
      '后台正在识别语音，请耐心等待': 'Processing transcription, please wait',
      '周末': 'Weekends',
      '复制分享链接': 'Copy share link',
      '复制链接': 'Copy link',
      '大小（字节，选填）': 'Size in bytes (optional)',
      '天气': 'Weather',
      '完成': 'Complete',
      '密码': 'Password',
      '密码已更新': 'Password updated',
      '密码长度至少 6 位': 'Password must be at least 6 characters',
      '将在设定时间提醒': 'You will be notified at the selected time',
      '尚未添加标签': 'No tags yet',
      '工作日': 'Weekdays',
      '已经有账号？去登录': 'Already have an account? Sign in',
      '开启后将在指定时间推送通知': 'Send notifications at the selected time when enabled',
      '开启提醒': 'Enable reminders',
      '录制语音': 'Record voice',
      '录音已上传，稍后将自动生成文本': 'Recording uploaded, text will be generated soon',
      '待办清单': 'To-do list',
      '心情': 'Mood',
      '快捷操作': 'Quick actions',
      '快速模板': 'Quick templates',
      '打卡安排': 'Check-in schedule',
      '提升账号安全等级': 'Level up your account security',
      '提醒设置': 'Reminder settings',
      '搜索历史': 'Search history',
      '搜索笔记、日记或习惯': 'Search notes, diaries or habits',
      '新建习惯': 'Create habit',
      '新建任务': 'Create task',
      '无法播放原音频': 'Unable to play the original audio',
      '无法播放该音频': 'Unable to play this audio',
      '日记记录': 'Diary log',
      '暂无提醒，可在编辑任务时添加': 'No reminders yet. Edit the task to add one.',
      '暂无正文内容。': 'No main content yet.',
      '暂无笔记，点击右下角创建第一条！': 'No notes yet. Tap the button below to create one!',
      '最近打卡': 'Recent check-ins',
      '未找到相关笔记': 'No related notes found',
      '查看全部': 'View all',
      '查看全部详情': 'View full details',
      '标签': 'Tags',
      '标记完成': 'Mark complete',
      '标题': 'Title',
      '正文内容': 'Body content',
      '此日记设为私密，若需分享可在编辑时开启“允许分享”。': 'This diary is private. Enable “Allow sharing” while editing to share it.',
      '每天': 'Daily',
      '没有找到匹配结果，换个关键词试试': 'No results found. Try another keyword.',
      '注册并登录': 'Sign up and log in',
      '添加': 'Add',
      '添加提醒': 'Add reminder',
      '添加标签': 'Add tag',
      '添加附件': 'Add attachment',
      '清除': 'Clear',
      '清除日期': 'Clear date',
      '清除筛选': 'Clear filters',
      '清除进度': 'Reset progress',
      '状态：': 'Status:',
      '界面语言': 'Interface language',
      '登录': 'Log in',
      '登录账号': 'Sign in to your account',
      '确定': 'Confirm',
      '确定删除该语音笔记吗？': 'Delete this voice note?',
      '确定要删除该任务吗？': 'Delete this task?',
      '确定要删除该任务吗？此操作无法撤销。': 'Delete this task? This action cannot be undone.',
      '确定要删除该笔记吗？该操作无法撤销。': 'Delete this note? This action cannot be undone.',
      '确定要删除该语音笔记吗？': 'Delete this voice note?',
      '私密': 'Private',
      '移除': 'Remove',
      '移除附件': 'Remove attachment',
      '立即录制': 'Record voice',
      '笔记': 'Notes',
      '简体中文': 'Simplified Chinese',
      '编辑': 'Edit',
      '编辑任务': 'Edit task',
      '编辑昵称': 'Edit nickname',
      '编辑附件': 'Edit attachment',
      '自定义/不定期': 'Custom / irregular',
      '记录生活点滴，随时管理与分享': 'Capture life moments to manage and share.',
      '设置多个提醒，在关键时间收到通知': 'Create reminders for important moments',
      '语音笔记': 'Voice notes',
      '语音笔记已保存': 'Voice note saved',
      '语音笔记已删除': 'Voice note deleted',
      '语音详情': 'Audio note detail',
      '请先录制语音': 'Please record audio first',
      '请先登录后再创建笔记': 'Please log in before creating a note',
      '请先登录账号': 'Please log in first',
      '请在习惯页面查看详情': 'View details on the Habits page',
      '请填写标题': 'Please enter a title',
      '请输入有效链接': 'Please enter a valid URL',
      '请输入标题': 'Please enter a title',
      '请输入正文内容': 'Please enter diary content',
      '请输入邮箱地址': 'Please enter your email address',
      '转写文本': 'Transcription',
      '输入关键词，快速查找你的内容': 'Enter keywords to search your content',
      '还没有内容': 'No content yet.',
      '还没有语音笔记，点击下方按钮开始录制灵感': 'No voice notes yet. Tap the button below to start recording ideas.',
      '进度': 'Progress',
      '邮箱': 'Email',
      '邮箱格式不正确': 'Invalid email format',
      '重复频率': 'Repeat frequency',
      '重新加载': 'Reload',
      '重试': 'Retry',
      '链接地址': 'Link URL',
      '附件': 'Attachments',
      '附件名称（选填）': 'Display name (optional)',

    },
  };

  String translate(String text) {
    if (locale.languageCode.startsWith('zh')) {
      return text;
    }
    return translateStatic(text);
  }

  static String translateStatic(String text) {
    return _translations['en']?[text] ?? text;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension LocalizationContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String t(String text) => l10n.translate(text);
}
