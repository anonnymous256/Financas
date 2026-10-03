import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../services/finance_engine.dart';
import 'common.dart';

class AppDestination {
  const AppDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

const destinations = <AppDestination>[
  AppDestination('/dashboard', 'Dashboard', Icons.space_dashboard_outlined),
  AppDestination('/transactions', 'Transações', Icons.swap_horiz),
  AppDestination('/incomes', 'Receitas', Icons.south_west),
  AppDestination('/expenses', 'Despesas', Icons.north_east),
  AppDestination('/accounts', 'Contas', Icons.account_balance_outlined),
  AppDestination('/cards', 'Cartões', Icons.credit_card),
  AppDestination('/invoices', 'Faturas', Icons.receipt_long_outlined),
  AppDestination('/transfers', 'Transferências', Icons.compare_arrows),
  AppDestination('/recurring', 'Contas recorrentes', Icons.event_repeat),
  AppDestination('/goals', 'Metas', Icons.flag_outlined),
  AppDestination('/reports', 'Relatórios', Icons.insights_outlined),
  AppDestination('/categories', 'Categorias', Icons.category_outlined),
  AppDestination('/settings', 'Configurações', Icons.settings_outlined),
  AppDestination('/profile', 'Meu perfil', Icons.person_outline),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      final actions = ref.read(financeActionsProvider);
      await actions.run((bundle) {
        final email = ref.read(authRepositoryProvider).currentEmail;
        if (email != null && email.isNotEmpty && bundle.profile.email != email) {
          FinanceEngine.changeEmail(bundle, email);
        }
        FinanceEngine.generateRecurring(bundle);
        FinanceEngine.refreshNotifications(bundle);
      });
    } catch (_) {}
  }

  int _mobileIndex(String location) {
    if (location.startsWith('/transactions') || location.startsWith('/incomes') || location.startsWith('/expenses')) {
      return 1;
    }
    if (location.startsWith('/accounts') || location.startsWith('/transfers')) return 2;
    if (location.startsWith('/cards') || location.startsWith('/invoices')) return 3;
    if (location.startsWith('/dashboard')) return 0;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final location = GoRouterState.of(context).uri.path;
    final wide = width >= 1100;
    final tablet = width >= 760;
    final profile = ref.watch(profileProvider).value;
    final unread = ref.watch(notificationsProvider).value?.where((item) => !item.read).length ?? 0;
    final cloud = ref.watch(firebaseReadyProvider);

    final sidebar = _Sidebar(
      compact: tablet && !wide,
      location: location,
      name: profile?.name ?? '',
      email: profile?.email ?? '',
      photoUrl: profile?.photoUrl ?? '',
      onNavigate: () => _scaffoldKey.currentState?.closeDrawer(),
    );

    final topBar = _TopBar(
      showMenu: !tablet,
      unread: unread,
      cloud: cloud,
      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
    );

    if (tablet) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(child: Column(children: [topBar, Expanded(child: widget.child)])),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: sidebar),
      body: Column(
        children: [
          topBar,
          Expanded(child: widget.child),
          NavigationBar(
            selectedIndex: _mobileIndex(location),
            onDestinationSelected: (index) {
              const paths = ['/dashboard', '/transactions', '/accounts', '/cards'];
              if (index == 4) {
                _scaffoldKey.currentState?.openDrawer();
                return;
              }
              context.go(paths[index]);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Início'),
              NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Movimentos'),
              NavigationDestination(icon: Icon(Icons.account_balance_outlined), label: 'Contas'),
              NavigationDestination(icon: Icon(Icons.credit_card), label: 'Cartões'),
              NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showMenu,
    required this.unread,
    required this.cloud,
    required this.onMenu,
  });

  final bool showMenu;
  final int unread;
  final bool cloud;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (showMenu) IconButton(onPressed: onMenu, icon: const Icon(Icons.menu)),
                if (!cloud)
                  const Expanded(
                    child: Text(
                      'Modo local neste aparelho. Configure o Firebase para salvar na nuvem.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  tooltip: 'Notificações',
                  onPressed: () => context.go('/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.compact,
    required this.location,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onNavigate,
  });

  final bool compact;
  final String location;
  final String name;
  final String email;
  final String photoUrl;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? 88 : 268,
      color: sidebarColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Finanças',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: destinations.map((item) {
                  final selected = location == item.path;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: compact ? item.label : '',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          onNavigate();
                          context.go(item.path);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF134E4A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                            children: [
                              Icon(item.icon, color: selected ? const Color(0xFF99F6E4) : const Color(0xFFCBD5E1), size: 22),
                              if (!compact) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: selected ? Colors.white : const Color(0xFFE2E8F0),
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (!compact)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: AvatarView(photoUrl: photoUrl, name: name),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      onTap: () => context.go('/profile'),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
                    leading: const Icon(Icons.logout, color: Color(0xFFFDA4AF)),
                    title: compact ? null : const Text('Sair', style: TextStyle(color: Color(0xFFFDA4AF))),
                    onTap: () => ref.read(sessionControllerProvider).signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
