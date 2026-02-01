import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          _NavigationSidebar(currentRoute: currentRoute),
          Expanded(
            child: Column(
              children: [
                _HeaderBar(title: title, actions: actions),
                Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _HeaderBar({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      height: 50,
      color: AppTheme.headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
                tooltip: 'Zurück',
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _NavigationSidebar extends StatelessWidget {
  final String currentRoute;

  const _NavigationSidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.sidebarColor,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // App Logo / Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.album, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Audiobook\nCreator',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Übersicht',
                  routeName: '/',
                  isActive: currentRoute == '/',
                ),
                const SizedBox(height: 4),
                _SidebarSectionHeader('WERKZEUGE'),
                _SidebarItem(
                  icon: Icons.disc_full_outlined,
                  title: 'CD-Ripper',
                  routeName: '/cd-ripper',
                  isActive: currentRoute == '/cd-ripper',
                ),
                _SidebarItem(
                  icon: Icons.search,
                  title: 'Metadaten Suche',
                  routeName: '/search',
                  isActive: currentRoute == '/search',
                ),
                _SidebarItem(
                  icon: Icons.tag,
                  title: 'Tag-Editor',
                  routeName: '/tag-editor',
                  isActive: currentRoute == '/tag-editor',
                ),
                _SidebarItem(
                  icon: Icons.menu_book,
                  title: 'Hörbuch erstellen',
                  routeName: '/audiobook',
                  isActive: currentRoute == '/audiobook',
                ),
                const SizedBox(height: 24),
                _SidebarSectionHeader('EINSTELLUNGEN'),
                _SidebarItem(
                  icon: Icons.settings_outlined,
                  title: 'Einstellungen',
                  routeName: '/settings',
                  isActive: currentRoute == '/settings',
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: const Color(0xFFFFDD00),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () async {
                  final uri = Uri.parse('https://buymeacoffee.com/jurzel');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.coffee, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Buy me a coffee',
                        style: GoogleFonts.cookie(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // User / Status area could go here
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  final String title;
  const _SidebarSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String routeName;
  final bool isActive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.routeName,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isActive) {
             // For root, we use pushNamedAndRemoveUntil to clear stack
             // For others, simply pushReplacement to swap content 
             // (simulating tabs without rewrite)
             if (routeName == '/') {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
             } else {
                 // To avoid infinite stack of replacements, we should probably 
                 // treat all sidebar items as top level. 
                 // However, we are in a sub-route. 
                 // We pop until first route? No, existing structure is simple.
                 // Let's just pushReplacementNamed.
                 Navigator.of(context).pushReplacementNamed(routeName);
             }
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
