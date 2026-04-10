import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/admin/admin_sidebar.dart';

enum AuditEventType {
  proposalCreated,
  statusUpdated,
  clientViewed,
  clientSigned,
  budgetUpdated,
}

enum DateRangePreset {
  last7,
  last30,
  last90,
  thisMonth,
  custom,
}

class AuditEvent {
  AuditEvent({
    required this.type,
    required this.timestamp,
    required this.proposalId,
    required this.proposalTitle,
    required this.summary,
    required this.actor,
  });

  final AuditEventType type;
  final DateTime timestamp;
  final String proposalId;
  final String proposalTitle;
  final String summary;
  final String actor;
}

class AdminHistoryPage extends StatefulWidget {
  const AdminHistoryPage({super.key});

  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage>
    with TickerProviderStateMixin {
  static const Color _adminBlockBase = Color(0xFF252525);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _proposalQueryCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;

  List<AuditEvent> _events = [];

  AuditEventType? _typeFilter;
  DateTimeRange? _dateRange;
  DateRangePreset _datePreset = DateRangePreset.last30;

  bool _initialised = false;

  String _currentPage = 'History';

  final DateFormat _timeFmt = DateFormat('HH:mm');
  final DateFormat _dateFmt = DateFormat('EEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _proposalQueryCtrl.addListener(_applyFilters);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _proposalQueryCtrl.dispose();
    super.dispose();
  }

  BoxDecoration _adminBlockDecoration(double radius) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          _adminBlockBase.withValues(alpha: 0.55),
          _adminBlockBase.withValues(alpha: 0.32),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _adminFrostedBlock({
    required Widget child,
    required double radius,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: _adminBlockDecoration(radius),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPageHeader(AppState app) {
    final user = AuthService.currentUser ?? app.currentUser ?? {};
    final email = user['email']?.toString() ?? 'admin@example.com';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Audit Trail',
              style: PremiumTheme.titleLarge,
            ),
            SizedBox(height: 4),
            Text(
              'Read-only activity across proposals, approvals, and client sign-off',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/User_Profile.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Admin',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  bool _isAdminUser() {
    final role = AuthService.currentUser?['role']?.toString().toLowerCase() ??
        'manager';
    return role == 'admin' || role == 'ceo';
  }

  Future<void> _load() async {
    if (!_isAdminUser()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/creator_dashboard');
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      AuthService.restoreSessionFromStorage();
      var token = AuthService.token;
      if (token == null) {
        await Future.delayed(const Duration(milliseconds: 400));
        token = AuthService.token;
      }
      if (token == null) {
        throw Exception('Session expired');
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final List<Map<String, dynamic>> proposals = [];
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final raw = (decoded is Map ? decoded['proposals'] : null);
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              proposals.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } else {
        throw Exception('Failed to load proposals (${response.statusCode})');
      }

      final events = _buildEvents(proposals);

      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
        _initialised = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  double? _parseBudget(dynamic value) {
    if (value is num) return value.toDouble();
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  String _proposalTitle(Map<String, dynamic> proposal) {
    final t = (proposal['title'] ?? proposal['proposalTitle'] ?? '')
        .toString()
        .trim();
    return t.isEmpty ? 'Untitled Proposal' : t;
  }

  String _proposalId(Map<String, dynamic> proposal) {
    return (proposal['id'] ?? '').toString();
  }

  String _actorFromProposal(Map<String, dynamic> proposal) {
    final owner = (proposal['owner_name'] ??
            proposal['ownerName'] ??
            proposal['owner_email'] ??
            proposal['ownerEmail'] ??
            proposal['owner_id'] ??
            proposal['ownerId'] ??
            '')
        .toString()
        .trim();
    return owner.isEmpty ? 'Unknown' : owner;
  }

  String _statusLabel(dynamic statusRaw) {
    final s = (statusRaw ?? '').toString().replaceAll('_', ' ').trim();
    if (s.isEmpty) return 'Status updated';
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  AuditEventType _classifyStatus(String statusLower) {
    if (statusLower.contains('signed') || statusLower.contains('client signed')) {
      return AuditEventType.clientSigned;
    }
    return AuditEventType.statusUpdated;
  }

  List<AuditEvent> _buildEvents(List<Map<String, dynamic>> proposals) {
    final List<AuditEvent> events = [];

    for (final proposal in proposals) {
      final id = _proposalId(proposal);
      if (id.isEmpty) continue;

      final title = _proposalTitle(proposal);
      final actor = _actorFromProposal(proposal);

      final createdAt = _parseDate(proposal['created_at'] ?? proposal['createdAt']);
      if (createdAt != null) {
        events.add(
          AuditEvent(
            type: AuditEventType.proposalCreated,
            timestamp: createdAt,
            proposalId: id,
            proposalTitle: title,
            summary: 'Proposal created',
            actor: actor,
          ),
        );
      }

      final updatedAt = _parseDate(proposal['updated_at'] ?? proposal['updatedAt']);
      final statusRaw = proposal['status'];
      final statusLower = (statusRaw ?? '').toString().toLowerCase();
      if (updatedAt != null) {
        final t = _classifyStatus(statusLower);
        final label = _statusLabel(statusRaw);
        final summary = t == AuditEventType.clientSigned
            ? 'Client signed'
            : 'Status updated: $label';

        events.add(
          AuditEvent(
            type: t,
            timestamp: updatedAt,
            proposalId: id,
            proposalTitle: title,
            summary: summary,
            actor: t == AuditEventType.clientSigned ? 'Client' : actor,
          ),
        );
      }

      final openedAt = _parseDate(
        proposal['engagement_opened_at'] ?? proposal['engagementOpenedAt'],
      );
      if (openedAt != null) {
        events.add(
          AuditEvent(
            type: AuditEventType.clientViewed,
            timestamp: openedAt,
            proposalId: id,
            proposalTitle: title,
            summary: 'Client viewed',
            actor: 'Client',
          ),
        );
      }

      final budget = _parseBudget(proposal['budget']);
      if (budget != null && updatedAt != null) {
        events.add(
          AuditEvent(
            type: AuditEventType.budgetUpdated,
            timestamp: updatedAt,
            proposalId: id,
            proposalTitle: title,
            summary: 'Budget updated: R${budget.toStringAsFixed(0)}',
            actor: actor,
          ),
        );
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  List<AuditEvent> _filteredEvents() {
    Iterable<AuditEvent> items = _events;

    if (_typeFilter != null) {
      items = items.where((e) => e.type == _typeFilter);
    }

    final proposalQuery = _proposalQueryCtrl.text.trim().toLowerCase();
    if (proposalQuery.isNotEmpty) {
      items = items.where((e) {
        return e.proposalId.toLowerCase().contains(proposalQuery) ||
            e.proposalTitle.toLowerCase().contains(proposalQuery);
      });
    }

    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
      );
      items = items.where((e) {
        return !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end);
      });
    }

    return items.toList();
  }

  void _applyFilters() {
    if (!_initialised) return;
    setState(() {});
  }

  String _typeLabel(AuditEventType type) {
    switch (type) {
      case AuditEventType.proposalCreated:
        return 'Proposal created';
      case AuditEventType.statusUpdated:
        return 'Status updated';
      case AuditEventType.clientViewed:
        return 'Client viewed';
      case AuditEventType.clientSigned:
        return 'Client signed';
      case AuditEventType.budgetUpdated:
        return 'Budget updated';
    }
  }

  Color _typeColor(AuditEventType type) {
    switch (type) {
      case AuditEventType.proposalCreated:
        return PremiumTheme.info;
      case AuditEventType.statusUpdated:
        return PremiumTheme.orange;
      case AuditEventType.clientViewed:
        return PremiumTheme.purple;
      case AuditEventType.clientSigned:
        return PremiumTheme.teal;
      case AuditEventType.budgetUpdated:
        return PremiumTheme.warning;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(
            const Duration(days: 30),
          ),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );

    if (!mounted) return;
    if (picked == null) return;

    setState(() {
      _dateRange = picked;
      _datePreset = DateRangePreset.custom;
    });
  }

  DateTimeRange _presetRange(DateRangePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case DateRangePreset.last7:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 7)),
          end: today,
        );
      case DateRangePreset.last30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: today,
        );
      case DateRangePreset.last90:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 90)),
          end: today,
        );
      case DateRangePreset.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case DateRangePreset.custom:
        return _dateRange ??
            DateTimeRange(
              start: today.subtract(const Duration(days: 30)),
              end: today,
            );
    }
  }

  String _presetLabel(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.last7:
        return 'Last 7 days';
      case DateRangePreset.last30:
        return 'Last 30 days';
      case DateRangePreset.last90:
        return 'Last 90 days';
      case DateRangePreset.thisMonth:
        return 'This month';
      case DateRangePreset.custom:
        return 'Custom range';
    }
  }

  Future<void> _applyPreset(DateRangePreset preset) async {
    if (preset == DateRangePreset.custom) {
      await _pickDateRange();
      return;
    }

    setState(() {
      _datePreset = preset;
      _dateRange = _presetRange(preset);
    });
  }

  InputDecoration _toolbarDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      prefixIcon: Icon(
        icon,
        color: Colors.white70,
        size: 18,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3498DB), width: 1.2),
      ),
    );
  }

  Widget _dateSectionHeader(DateTime day) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Text(
            _dateFmt.format(day),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetDropdown() {
    final suffix = (_datePreset == DateRangePreset.custom && _dateRange != null)
        ? ' (${DateFormat('d MMM').format(_dateRange!.start)} → ${DateFormat('d MMM').format(_dateRange!.end)})'
        : '';

    return SizedBox(
      width: 200,
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<DateRangePreset>(
          initialValue: _datePreset,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          iconEnabledColor: Colors.white70,
          decoration: _toolbarDecoration(
            hintText: 'Date range',
            icon: Icons.date_range,
          ),
          items: [
            for (final p in DateRangePreset.values)
              DropdownMenuItem<DateRangePreset>(
                value: p,
                child: Text(
                  '${_presetLabel(p)}${p == DateRangePreset.custom ? suffix : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (val) {
            if (val == null) return;
            _applyPreset(val);
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final typeDrop = SizedBox(
          width: 180,
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<AuditEventType?>(
              initialValue: _typeFilter,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              iconEnabledColor: Colors.white70,
              decoration: _toolbarDecoration(
                hintText: 'Event type',
                icon: Icons.category_outlined,
              ),
              items: [
                const DropdownMenuItem<AuditEventType?>(
                  value: null,
                  child: Text('All'),
                ),
                for (final t in AuditEventType.values)
                  DropdownMenuItem<AuditEventType?>(
                    value: t,
                    child: Text(_typeLabel(t)),
                  ),
              ],
              onChanged: (val) {
                setState(() {
                  _typeFilter = val;
                });
              },
            ),
          ),
        );

        final searchField = TextField(
          controller: _proposalQueryCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _toolbarDecoration(
            hintText: 'Search proposal title or ID',
            icon: Icons.search,
          ),
        );

        final refreshBtn = InkWell(
          onTap: _load,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.refresh,
              color: Colors.white70,
              size: 20,
            ),
          ),
        );

        const fixedWidth = 180.0 + 200.0 + 38.0;
        const gaps = 12.0 * 3;
        final availableForSearch = constraints.maxWidth - fixedWidth - gaps;
        final maxAllowed = (constraints.maxWidth - fixedWidth - gaps)
            .clamp(0.0, double.infinity);
        final searchWidth = availableForSearch
            .clamp(160.0, 520.0)
            .clamp(0.0, maxAllowed)
            .clamp(0.0, constraints.maxWidth);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            typeDrop,
            SizedBox(
              width: searchWidth == 0 ? constraints.maxWidth : searchWidth,
              child: searchField,
            ),
            _buildDatePresetDropdown(),
            refreshBtn,
          ],
        );
      },
    );
  }

  Map<DateTime, List<AuditEvent>> _groupByDate(List<AuditEvent> events) {
    final Map<DateTime, List<AuditEvent>> grouped = {};
    for (final e in events) {
      final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: grouped[k]!};
  }

  Widget _buildTableHeader() {
    return Row(
      children: const [
        Expanded(
          flex: 2,
          child: Text(
            'Time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            'Event',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'Type',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            'Proposal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(AuditEvent e) {
    final color = _typeColor(e.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _typeLabel(e.type),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTableRow(AuditEvent e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _timeFmt.format(e.timestamp.toLocal()),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              e.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildTypeChip(e),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '#${e.proposalId} · ${e.proposalTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(List<AuditEvent> events) {
    final grouped = _groupByDate(events);

    if (events.isEmpty) {
      return _adminFrostedBlock(
        radius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 40, color: Colors.white70),
            SizedBox(height: 12),
            Text(
              'No history found for these filters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try clearing filters or expanding the date range.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final content = <Widget>[];
    bool first = true;
    for (final entry in grouped.entries) {
      if (!first) {
        content.add(const SizedBox(height: 6));
      }
      first = false;

      content.add(_dateSectionHeader(entry.key));

      for (var i = 0; i < entry.value.length; i++) {
        content.add(_buildTableRow(entry.value[i]));
        if (i < entry.value.length - 1) {
          content.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          );
        }
      }
    }

    const minTableWidth = 820.0;

    Widget tableBlock(double width) {
      return SizedBox(
        width: width,
        child: _adminFrostedBlock(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableHeader(),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 4),
              ...content,
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final width = availableWidth >= minTableWidth
            ? availableWidth
            : minTableWidth;

        if (availableWidth >= minTableWidth) {
          return tableBlock(width);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: tableBlock(width),
        );
      },
    );
  }

  void _navigateToPage(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Approvals':
        Navigator.pushReplacementNamed(context, '/admin_approvals');
        break;
      case 'Analytics':
        Navigator.pushReplacementNamed(context, '/admin_analytics');
        break;
      case 'History':
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Sign Out':
      case 'Logout':
        AuthService.logout();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final events = _filteredEvents();

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPageHeader(app),
        const SizedBox(height: 24),
        Expanded(
          child: _adminFrostedBlock(
            radius: 32,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'A read-only log of proposal activity',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                          ? Center(
                              child: Text(
                                _loadError!,
                                style: PremiumTheme.bodyLarge
                                    .copyWith(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : CustomScrollbar(
                              controller: _scrollController,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: _buildHistoryTable(events),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  child: AdminSidebar(
                    isCollapsed: app.isAdminSidebarCollapsed,
                    currentPage: _currentPage,
                    onToggle: app.toggleAdminSidebar,
                    onSelect: (label) {
                      setState(() => _currentPage = label);
                      _navigateToPage(label);
                    },
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: main,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
