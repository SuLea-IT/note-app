import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/features/home/application/home_controller.dart';
import 'package:frontend/features/home/presentation/home_screen.dart';
import 'package:frontend/features/home/presentation/widgets/note_section_view.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    Intl.defaultLocale = 'zh_CN';
  });

  testWidgets('Home feed loads mocked sections', (tester) async {
    await tester.pumpWidget(const NoteApp(useRemote: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final homeFinder = find.byType(HomeScreen);
    expect(homeFinder, findsOneWidget);

    final context = tester.element(homeFinder);
    final controller = Provider.of<HomeController>(context, listen: false);
    expect(controller.state.status, HomeStatus.ready);
    expect(controller.state.feed?.sections.length ?? 0, greaterThan(0));

    expect(find.byType(NoteSectionView), findsWidgets);
  });
}
