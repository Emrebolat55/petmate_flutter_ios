import 'package:flutter/material.dart';
import 'ads_list_page.dart';

class MatingPage extends StatelessWidget {
  const MatingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdsListPage(
      filterType: 'Çiftleştirme',
    );
  }
}