import 'package:cross_platform_chat_app/pages/accounts/app_accounts_linked_page.dart';
import 'package:cross_platform_chat_app/pages/chat_list/chat_list_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cross_platform_chat_app/theme/app_colors.dart';

import '../../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;

  // 🔍 Arama değişkenleri
  bool isSearching = false;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void startSearch() {
    setState(() {
      isSearching = true;
    });
  }

  void stopSearch() {
    setState(() {
      isSearching = false;
      searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final List<Widget> pages = [
      ChatListPage(searchQuery: searchQuery),
      const AccountsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryy(brightness).withOpacity(0.1), // veya AppColors.background(brightness)
      appBar: AppBar(
        shadowColor: AppColors.primaryy(brightness).withOpacity(0.2),
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.primaryy(brightness),
        title: currentPageIndex == 0
            ? (isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          cursorColor: AppColors.primaryy(brightness).withOpacity(0.1),
          style:  TextStyle(color: AppColors.text(brightness)),
          decoration:  InputDecoration(
            hintText: 'Sohbet Ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.text(brightness)),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        )
            : const Text(
          'CHATTY',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontFamily: "MyTitleFont",
          ),
        ))
            : const Text(
          'CHATTY',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontFamily: "MyTitleFont",
          ),
        ),
        leading: currentPageIndex == 0 && isSearching
            ? IconButton(
          icon:  Icon(Icons.arrow_back, color: AppColors.text(brightness)),
          onPressed: stopSearch,
        )
            : null,
        actions: [
          // Arama ikonu
          if (currentPageIndex == 0 && !isSearching)
            IconButton(
              onPressed: startSearch,
              icon:  Icon(Icons.search, color: AppColors.text(brightness)),
              padding: const EdgeInsets.only(right: 8),
              iconSize: 28,
            ),

          // Tema değiştirme ikonu
          IconButton(
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
              color: AppColors.text(brightness),
              size: 28,
            ),
            padding: const EdgeInsets.only(right: 16),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.primaryy(brightness),
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
            if (index != 0) stopSearch();
          });
        },
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: AppColors.text(brightness)),
        ),
        indicatorColor: Colors.amber,

        selectedIndex: currentPageIndex,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Sohbetler',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_tree_rounded),
            icon: Icon(Icons.account_tree_outlined),
            label: 'Hesaplar',

          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_circle),
            icon: Icon(Icons.account_circle_outlined),
            label: 'Profil',
          ),
        ],
      ),
      body: pages[currentPageIndex],
    );

  }
}
