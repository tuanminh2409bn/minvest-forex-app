// lib/app/main_screen_web.dart

import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/auth/screens/profile_screen.dart';
import 'package:minvest_forex_app/features/chart/screens/chart_screen.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các trang không thay đổi
  static const List<Widget> _pages = <Widget>[
    SignalScreen(),
    ChartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // DÙNG LAYOUTBUILDER ĐỂ QUYẾT ĐỊNH GIAO DIỆN
    return LayoutBuilder(
      builder: (context, constraints) {
        // Nếu màn hình đủ rộng (lớn hơn 640px), dùng giao diện web với NavigationRail
        if (constraints.maxWidth > 640) {
          return _buildWideLayout(context);
        } else {
          // Nếu màn hình hẹp, dùng lại giao diện mobile với BottomNavigationBar
          return _buildNarrowLayout(context);
        }
      },
    );
  }

  // Giao diện cho màn hình rộng (Web/Desktop)
  Widget _buildWideLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Row(
        children: <Widget>[
          // THANH ĐIỀU HƯỚNG BÊN TRÁI
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all, // Hiển thị cả icon và label
            backgroundColor: const Color(0xFF0D1117), // Màu nền đồng bộ
            indicatorColor: const Color(0xFF161B22), // Màu của mục được chọn
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
            selectedLabelTextStyle: const TextStyle(color: Colors.white),
            unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600),

            destinations: <NavigationRailDestination>[
              NavigationRailDestination(
                icon: const Icon(Icons.signal_cellular_alt),
                label: Text(l10n.tabSignal),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.bar_chart),
                label: Text(l10n.tabChart),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: Text(l10n.tabProfile),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.black),
          // NỘI DUNG TRANG CHÍNH
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  // Giao diện cho màn hình hẹp (tái sử dụng code từ main_screen_mobile.dart)
  Widget _buildNarrowLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.signal_cellular_alt),
            label: l10n.tabSignal,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: l10n.tabChart,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.tabProfile,
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.black.withOpacity(0.8),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
      ),
    );
  }
}