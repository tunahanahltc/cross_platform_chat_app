import 'package:cross_platform_chat_app/pages/accounts/app_accounts_linked_page.dart';
import 'package:cross_platform_chat_app/pages/chat_list/chat_list_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';

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
    final List<Widget> pages = [
      ChatListPage(searchQuery: searchQuery),
      const AccountsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        title: currentPageIndex == 0 // 🆕 Sadece Sohbetler sayfasında arama
            ? (isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          cursorColor: Colors.black,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: 'Sohbet Ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black54),
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
        leading: currentPageIndex == 0 && isSearching // 🔙 Geri tuşu sadece Sohbetlerde ve arama açıkken
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: stopSearch,
        )
            : null,
        actions: currentPageIndex == 0 && !isSearching // 🔍 Arama ikonu sadece Sohbetlerde ve arama kapalıyken
            ? [
          IconButton(
            onPressed: startSearch,
            icon: const Icon(Icons.search, color: Colors.black),
            padding: const EdgeInsets.only(right: 20),
            iconSize: 30,
          ),
        ]
            : [],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,

        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
            if (index != 0) {
              // Sohbetler dışına çıkınca aramayı kapat
              stopSearch();
            }
          });
        },
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
