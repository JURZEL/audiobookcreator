import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/cd_info_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/musicbrainz_search_screen.dart';
import 'screens/audiobook_creator_screen.dart';
import 'screens/tag_editor_screen.dart';
import 'models/ripping_config.dart';
import 'providers/app_providers.dart';

void main() {
  runApp(const ProviderScope(child: CDRipperApp()));
}

class CDRipperApp extends StatelessWidget {
  const CDRipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CD Ripper Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(AppTheme.darkTheme.textTheme),
      ),
      home: const _StartupWrapper(),
      onGenerateRoute: (settings) {
        if (settings.name == '/cd-ripper') {
          return MaterialPageRoute(builder: (context) => const CDInfoScreen());
        }
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const HomeScreen());
        }
        if (settings.name == '/export') {
          final config = settings.arguments as RippingConfig?;
          return MaterialPageRoute(
            builder: (context) => ExportScreen(config: config),
          );
        }
        if (settings.name == '/settings') {
          return MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          );
        }
        if (settings.name == '/search') {
          return MaterialPageRoute(
            builder: (context) => const MusicBrainzSearchScreen(),
          );
        }
        if (settings.name == '/audiobook') {
          return MaterialPageRoute(
            builder: (context) => const AudiobookCreatorScreen(),
          );
        }
        if (settings.name == '/tag-editor') {
          return MaterialPageRoute(
            builder: (context) => const TagEditorScreen(),
          );
        }
        return null;
      },
    );
  }
}

/// Wrapper that checks for missing email on startup
class _StartupWrapper extends ConsumerStatefulWidget {
  const _StartupWrapper();

  @override
  ConsumerState<_StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends ConsumerState<_StartupWrapper> {
  bool _informedAboutEmail = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    settings.when(
      data: (email) {
        if ((email == null || email.isEmpty) && !_informedAboutEmail) {
          _informedAboutEmail = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('MusicBrainz: Kontakt-E-Mail fehlt'),
                  content: const Text(
                    'Um MusicBrainz nutzen zu können, geben Sie bitte eine Kontakt-E-Mail in den Einstellungen ein.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Später'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/settings');
                      },
                      child: const Text('Zu Einstellungen'),
                    ),
                  ],
                ),
              );
            }
          });
        }
      },
      loading: () {},
      error: (_, stack) {},
    );

    return const HomeScreen();
  }
}
