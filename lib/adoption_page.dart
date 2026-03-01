import 'package:flutter/material.dart';
import 'ads_list_page.dart';

class AdoptionPage extends StatelessWidget {
  const AdoptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdsListPage(
      filterType: 'Sahiplendirme',
    );
  }
}