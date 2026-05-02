import 'package:flutter/material.dart';
import '../Auth/colors.dart';
import 'ResetStudentAccountPage.dart';
import 'ResetStudentsForNewYearPage.dart';

class ResetStudentsAccountsPage extends StatelessWidget {
  const ResetStudentsAccountsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.lightColor2,
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          title: const Text(
            'Reset Accounts',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Single Account', icon: Icon(Icons.person_off)),
              Tab(text: 'New Year Reset', icon: Icon(Icons.autorenew)),
            ],
          ),
          elevation: 0,
        ),
        body: const TabBarView(
          children: [
            ResetStudentAccountPage(isTab: true),
            ResetStudentsForNewYearPage(isTab: true),
          ],
        ),
      ),
    );
  }
}
