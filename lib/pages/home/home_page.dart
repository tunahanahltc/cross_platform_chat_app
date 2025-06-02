import 'package:cross_platform_chat_app/pages/accounts/app_accounts_linked_page.dart';
import 'package:cross_platform_chat_app/pages/chat_list/chat_list_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  final List<Widget> pages = [
    ChatListPage(),
    const AccountsPage(),
    const ProfilePage(),
  ];
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'CHATTY',
          style: TextStyle(color: Colors.orangeAccent, fontFamily: "MyTitleFont"),
        ),
        backgroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search button')),
              );
            },
            icon: const Icon(Icons.search, color: Colors.black),
            padding: const EdgeInsets.only(right: 20),
            iconSize: 30,
          ),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
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
