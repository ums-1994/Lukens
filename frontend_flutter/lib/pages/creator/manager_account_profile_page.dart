import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/local_profile_avatar_store.dart';
import '../../theme/manager_theme_controller.dart';
import '../../theme/premium_theme.dart';
import '../../utils/manager_session_actions.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/manager_page_background.dart';

class ManagerAccountProfilePage extends StatefulWidget {
  const ManagerAccountProfilePage({super.key});

  @override
  State<ManagerAccountProfilePage> createState() =>
      _ManagerAccountProfilePageState();
}

class _ManagerAccountProfilePageState extends State<ManagerAccountProfilePage> {
  Uint8List? _localFallbackBytes;
  bool _loadingAvatar = true;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().setCurrentNavLabel('Account Profile');
      _reloadProfile();
    });
  }

  Future<void> _reloadProfile() async {
    final app = Provider.of<AppState>(context, listen: false);
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
    }
    if (app.authToken != null) {
      await app.fetchCurrentUser();
    }
    final user = AuthService.currentUser ?? app.currentUser;
    final bytes = await LocalProfileAvatarStore.loadForUser(user);
    if (mounted) {
      setState(() {
        _localFallbackBytes = bytes;
        _loadingAvatar = false;
      });
    }
  }

  String? _cloudinaryProfileUrl(Map<String, dynamic> user) {
    final u = user['profile_image_url']?.toString().trim();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  bool _hasAnyAvatar(Map<String, dynamic> user) {
    return _cloudinaryProfileUrl(user) != null || _localFallbackBytes != null;
  }

  bool _isAdminUser() {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;
      final role = (user['role']?.toString() ?? '').toLowerCase().trim();
      return role == 'admin' || role == 'ceo';
    } catch (_) {
      return false;
    }
  }

  String _displayName(Map<String, dynamic>? u) {
    if (u == null) return '—';
    for (final key in ['full_name', 'name', 'display_name', 'username']) {
      final v = u[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final email = u['email']?.toString().trim();
    return email?.isNotEmpty == true ? email! : '—';
  }

  void _navigateToPage(BuildContext context, String label) {
    final isAdmin = _isAdminUser();

    switch (label) {
      case 'Dashboard':
        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
        }
        break;
      case 'My Proposals':
      case 'Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client_management');
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Account Profile':
        break;
      case 'Logout':
        ManagerSessionActions.showLogoutDialog(context);
        break;
      default:
        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
        }
    }
  }

  Future<void> _pickAndSaveAvatar() async {
    final app = Provider.of<AppState>(context, listen: false);
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
    }
    final user = AuthService.currentUser ?? app.currentUser;
    if (user == null || app.authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in.')),
      );
      return;
    }

    setState(() => _savingAvatar = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) {
        if (mounted) setState(() => _savingAvatar = false);
        return;
      }
      final bytes = await file.readAsBytes();
      const maxBytes = 750 * 1024;
      if (bytes.length > maxBytes) {
        if (mounted) {
          setState(() => _savingAvatar = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large. Try a smaller photo.'),
            ),
          );
        }
        return;
      }

      final uploadResult = await app.uploadImageToCloudinary(
        '',
        fileBytes: bytes,
        fileName: file.name,
      );

      if (uploadResult == null ||
          uploadResult['url'] == null ||
          uploadResult['public_id'] == null) {
        throw Exception('Upload failed');
      }

      final url = uploadResult['url'].toString();
      final publicId = uploadResult['public_id'].toString();

      final updated = await app.patchUserProfileAvatar(
        profileImageUrl: url,
        profileImagePublicId: publicId,
      );

      if (updated == null) {
        throw Exception('Could not save profile on server');
      }

      await LocalProfileAvatarStore.clearForCurrentUser(user);

      if (mounted) {
        setState(() {
          _localFallbackBytes = null;
          _savingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture saved (Cloudinary).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    final app = Provider.of<AppState>(context, listen: false);
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
    }
    final user = AuthService.currentUser ?? app.currentUser;

    setState(() => _savingAvatar = true);
    try {
      if (app.authToken != null && _cloudinaryProfileUrl(user ?? {}) != null) {
        await app.clearUserProfileAvatar();
      }
      await LocalProfileAvatarStore.clearForCurrentUser(user);
      if (mounted) {
        setState(() {
          _localFallbackBytes = null;
          _savingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove photo: $e')),
        );
      }
    }
  }

  Widget _buildAvatarPhoto(
    ManagerChromeTheme chrome,
    Map<String, dynamic> user,
  ) {
    final url = _cloudinaryProfileUrl(user);
    if (url != null) {
      return ClipOval(
        child: Image.network(
          url,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (_localFallbackBytes != null) {
              return Image.memory(
                _localFallbackBytes!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              );
            }
            return Container(
              width: 96,
              height: 96,
              color: chrome.fieldFill,
              child: Icon(Icons.person, size: 48, color: chrome.textMuted),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 96,
              height: 96,
              color: chrome.fieldFill,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chrome.textMuted,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    if (_localFallbackBytes != null) {
      return ClipOval(
        child: Image.memory(
          _localFallbackBytes!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: chrome.fieldFill,
      child: Icon(Icons.person, size: 48, color: chrome.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final user = AuthService.currentUser ?? app.currentUser ?? {};
    final role = (user['role'] ?? '—').toString();
    final email = (user['email'] ?? '—').toString();
    final department = (user['department'] ?? '').toString().trim();
    final company =
        (user['company_name'] ?? user['company'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ManagerPageBackground(
        child: Row(
          children: [
            Consumer<AppState>(
              builder: (context, appState, _) {
                final u = AuthService.currentUser ?? appState.currentUser;
                final r = (u?['role'] ?? '').toString().toLowerCase().trim();
                final isAdmin = r == 'admin' ||
                    r == 'ceo' ||
                    r == 'manager' ||
                    r == 'creator' ||
                    r == 'financial manager';
                return AppSideNav(
                  isCollapsed: appState.isSidebarCollapsed,
                  currentLabel: appState.currentNavLabel,
                  isAdmin: isAdmin,
                  onToggle: appState.toggleSidebar,
                  onSelect: (label) {
                    appState.setCurrentNavLabel(label);
                    _navigateToPage(context, label);
                  },
                );
              },
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                      child: Text(
                        'Account profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: chrome.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: chrome.floatingPanelDecoration(radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: _loadingAvatar
                                      ? CircleAvatar(
                                          radius: 48,
                                          backgroundColor: chrome.fieldFill,
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: chrome.textMuted,
                                            ),
                                          ),
                                        )
                                      : _buildAvatarPhoto(
                                          chrome,
                                          Map<String, dynamic>.from(user),
                                        ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(user.isEmpty
                                            ? null
                                            : Map<String, dynamic>.from(
                                                user)),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: chrome.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: chrome.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton.icon(
                                            onPressed: _savingAvatar
                                                ? null
                                                : _pickAndSaveAvatar,
                                            icon: _savingAvatar
                                                ? SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .photo_camera_outlined,
                                                    size: 20,
                                                  ),
                                            label: Text(_savingAvatar
                                                ? 'Saving…'
                                                : 'Upload photo'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  PremiumTheme.primaryRed,
                                            ),
                                          ),
                                          if (_hasAnyAvatar(
                                              Map<String, dynamic>.from(
                                                  user)))
                                            TextButton(
                                              onPressed: _savingAvatar
                                                  ? null
                                                  : _removeAvatar,
                                              child: Text(
                                                'Remove photo',
                                                style: TextStyle(
                                                  color: chrome.textSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Photos upload to Cloudinary and are saved on your account so they follow you across devices.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: chrome.textMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Divider(color: chrome.divider),
                            const SizedBox(height: 16),
                            _detailRow(chrome, 'Role', role),
                            _detailRow(chrome, 'Email', email),
                            if (department.isNotEmpty)
                              _detailRow(chrome, 'Department', department),
                            if (company.isNotEmpty)
                              _detailRow(chrome, 'Company', company),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ManagerChromeTheme chrome, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: chrome.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 14,
                color: chrome.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
