import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:petmate_flutter/l10n/generated/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _autoLogin = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    if (_currentUser != null) {
      try {
        final snapshot = await _database
            .child('users')
            .child(_currentUser!.uid)
            .child('settings')
            .get();

        if (snapshot.exists) {
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _notificationsEnabled = data['notifications'] ?? true;
            _locationEnabled = data['location'] ?? true;
            _autoLogin = data['autoLogin'] ?? true;
          });
        }
      } catch (e) {
        print('Ayarlar yükleme hatası: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final loc = AppLocalizations.of(context)!;
    if (_currentUser != null) {
      setState(() => _isSaving = true);
      try {
        await _database
            .child('users')
            .child(_currentUser!.uid)
            .child('settings')
            .update({
          'notifications': _notificationsEnabled,
          'location': _locationEnabled,
          'autoLogin': _autoLogin,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.settingsSaved),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.settingsError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    final loc = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.editProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: loc.fullName,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _currentUser?.updateDisplayName(nameController.text);
                await _database
                    .child('users')
                    .child(_currentUser!.uid)
                    .update({
                  'name': nameController.text,
                  'updatedAt': DateTime.now().toIso8601String(),
                });
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.profileUpdated),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${loc.updateError}: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final loc = AppLocalizations.of(context)!;
    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPassController,
              decoration: InputDecoration(
                labelText: loc.newPassword,
                border: OutlineInputBorder(),
                hintText: loc.minChars,
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 8),
            Text(
              loc.passwordHint,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.passwordTooShort),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await _currentUser?.updatePassword(newPassController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.passwordChanged),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                String message = loc.passwordChangeError;
                if (e.code == 'requires-recent-login') {
                  message = loc.reloginRequired;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(loc.change),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    final loc = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController(
      text: _currentUser?.email ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.changeEmail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: loc.newEmail,
                border: OutlineInputBorder(),
                hintText: 'example@email.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 8),
            Text(
              loc.emailVerificationNote,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _currentUser?.verifyBeforeUpdateEmail(controller.text);
                await _database
                    .child('users')
                    .child(_currentUser!.uid)
                    .update({'email': controller.text});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.verificationSent),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${loc.emailChangeError}: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(loc.change),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteAccount),
        content: Text(loc.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.lastWarning),
                  content: Text(loc.deleteAccountWarning),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.no),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performAccountDeletion();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text(loc.yesDelete),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.deleteAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    final loc = AppLocalizations.of(context)!;
    try {
      await _database.child('users').child(_currentUser!.uid).remove();
      await _currentUser?.delete();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = loc.accountDeleteError;
      if (e.code == 'requires-recent-login') {
        message = loc.reloginRequiredDelete;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$message: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.accountDeleteFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotOpenLink),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rateApp() async {
    final loc = AppLocalizations.of(context)!;
    const String appId = 'com.bolatsoft.petmate';
    const String playStoreUrl =
        'https://play.google.com/store/apps/details?id=$appId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.rateApp),
        content: Text(loc.rateAppContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchURL(playStoreUrl);
            },
            child: Text(loc.rate),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(loc.helpSupport,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: Icon(Icons.email, color: Colors.blue),
              ),
              title: Text(loc.emailSupport),
              subtitle: Text('destek@petmate.com'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('mailto:destek@petmate.com');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[50],
                child: Icon(Icons.phone, color: Colors.green),
              ),
              title: Text(loc.phoneSupport),
              subtitle: Text('+90 555 123 4567'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('tel:+905551234567');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[50],
                child: Icon(Icons.question_answer, color: Colors.orange),
              ),
              title: Text(loc.faq),
              subtitle: Text(loc.faqSubtitle),
              onTap: () {
                Navigator.pop(context);
                _launchURL('https://petmate.com/faq');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.privacyPolicy),
        content: SingleChildScrollView(
          child: Text(
            loc.privacyPolicyContent,
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.close),
          ),
        ],
      ),
    );
  }

  void _showTermsConditions() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.termsConditions),
        content: SingleChildScrollView(
          child: Text(
            loc.termsContent,
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.close),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentLocale = localeProvider.locale;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              name: 'Türkçe 🇹🇷',
              locale: Locale('tr'),
              currentLocale: currentLocale,
              onTap: () {
                localeProvider.setLocale(Locale('tr'));
                Navigator.pop(context);
              },
            ),
            _buildLanguageOption(
              name: 'English 🇬🇧',
              locale: Locale('en'),
              currentLocale: currentLocale,
              onTap: () {
                localeProvider.setLocale(Locale('en'));
                Navigator.pop(context);
              },
            ),
            _buildLanguageOption(
              name: 'Deutsch 🇩🇪',
              locale: Locale('de'),
              currentLocale: currentLocale,
              onTap: () {
                localeProvider.setLocale(Locale('de'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String name,
    required Locale locale,
    required Locale currentLocale,
    required VoidCallback onTap,
  }) {
    final bool isSelected = currentLocale.languageCode == locale.languageCode;
    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Colors.blue[800])
          : Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isSelected ? Colors.blue[50] : null,
    );
  }

  void _logout() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.logout),
        content: Text(loc.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.logout),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);

    final Map<String, String> localeNames = {
      'tr': 'Türkçe 🇹🇷',
      'en': 'English 🇬🇧',
      'de': 'Deutsch 🇩🇪',
    };
    final currentLangName = localeNames[localeProvider.locale.languageCode] ?? 'Türkçe';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          _isSaving
              ? Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _saveSettings,
                  tooltip: loc.saveSettings,
                ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ─── Kullanıcı Profil Kartı ───
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, color: Colors.blue[800], size: 30),
              ),
              title: Text(
                _currentUser?.displayName ??
                    _currentUser?.email?.split('@').first ??
                    loc.guest,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(_currentUser?.email ?? loc.noEmail),
              trailing: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: Colors.blue[800]),
              ),
              onTap: _updateProfile,
            ),
          ),

          SizedBox(height: 20),

          // ─── Genel Ayarlar ───
          _buildSectionHeader(Icons.tune, loc.generalSettings),
          SizedBox(height: 8),

          _buildSettingSwitch(
            title: loc.notifications,
            subtitle: loc.notificationsSubtitle,
            value: _notificationsEnabled,
            icon: Icons.notifications_active,
            iconColor: Colors.orange,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),

          _buildSettingSwitch(
            title: loc.locationService,
            subtitle: loc.locationSubtitle,
            value: _locationEnabled,
            icon: Icons.location_on,
            iconColor: Colors.green,
            onChanged: (value) {
              setState(() => _locationEnabled = value);
              if (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.locationEnabled),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),

          _buildSettingSwitch(
            title: loc.autoLogin,
            subtitle: loc.autoLoginSubtitle,
            value: _autoLogin,
            icon: Icons.login,
            iconColor: Colors.purple,
            onChanged: (value) => setState(() => _autoLogin = value),
          ),

          SizedBox(height: 20),

          // ─── Dil Ayarı ───
          _buildSectionHeader(Icons.language, loc.languageRegion),
          SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.language, color: Colors.blue[800]),
              ),
              title: Text(loc.appLanguage),
              subtitle: Text(currentLangName),
              trailing: Icon(Icons.chevron_right, color: Colors.blue[800]),
              onTap: _showLanguagePicker,
            ),
          ),

          SizedBox(height: 20),

          // ─── Hesap Ayarları ───
          _buildSectionHeader(Icons.manage_accounts, loc.accountSettings),
          SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.lock,
                  iconColor: Colors.orange,
                  title: loc.changePassword,
                  onTap: _changePassword,
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.email,
                  iconColor: Colors.blue,
                  title: loc.changeEmail,
                  onTap: _changeEmail,
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.delete_forever,
                  iconColor: Colors.red,
                  title: loc.deleteAccount,
                  onTap: _deleteAccount,
                  titleColor: Colors.red,
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // ─── Hakkında ───
          _buildSectionHeader(Icons.info_outline, loc.about),
          SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.verified,
                  iconColor: Colors.grey,
                  title: loc.version,
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  onTap: () {},
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.privacy_tip,
                  iconColor: Colors.blue,
                  title: loc.privacyPolicy,
                  onTap: _showPrivacyPolicy,
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.description,
                  iconColor: Colors.teal,
                  title: loc.termsConditions,
                  onTap: _showTermsConditions,
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.help_outline,
                  iconColor: Colors.purple,
                  title: loc.helpSupport,
                  onTap: _showHelpSupport,
                ),
                Divider(height: 1, indent: 72),
                _buildActionTile(
                  icon: Icons.star_rate,
                  iconColor: Colors.amber,
                  title: loc.rateApp,
                  onTap: _rateApp,
                ),
              ],
            ),
          ),

          SizedBox(height: 30),

          // ─── Çıkış Yap ───
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: Icon(Icons.logout),
              label: Text(loc.logout,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          Center(
            child: Text(
              'PetMate v1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[800]),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color iconColor,
    required Function(bool) onChanged,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        secondary: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue[800],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}