import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';

enum ProposalLifecycleStage {
  draft,
  inReview,
  released,
  signed,
  unknown,
}

enum ProposalApprovalState {
  readyForApproval,
  blocked,
  changesRequested,
  approved,
  declined,
  unknown,
}

class ProposalStatusVocabulary {
  static String extractRawStatus(Map<String, dynamic> proposal) {
    return (proposal['status'] ??
            proposal['proposal_status'] ??
            proposal['proposalStatus'] ??
            proposal['approval_status'] ??
            proposal['approvalStatus'] ??
            proposal['state'] ??
            proposal['stage'] ??
            '')
        .toString();
  }

  static String normalize(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ');
  }

  static String titleCase(dynamic value, {String emptyLabel = '—'}) {
    final s = (value ?? '').toString().replaceAll('_', ' ').trim();
    if (s.isEmpty) return emptyLabel;

    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static ProposalLifecycleStage lifecycleStageFromStatus(String normalizedStatus) {
    final s = normalizedStatus.trim();
    if (s.isEmpty || s.contains('draft')) return ProposalLifecycleStage.draft;

    if (s.contains('signed') ||
        s.contains('client signed') ||
        s.contains('completed') ||
        s.contains('won')) {
      return ProposalLifecycleStage.signed;
    }

    if (s.contains('sent to client') ||
        s.contains('released') ||
        s == 'sent' ||
        s.contains('shared') ||
        s.contains('sent for signature') ||
        s.contains('out for signature')) {
      return ProposalLifecycleStage.released;
    }

    if (s.contains('review') ||
        s.contains('submitted') ||
        s.contains('pending') ||
        s.contains('approved')) {
      return ProposalLifecycleStage.inReview;
    }

    return ProposalLifecycleStage.unknown;
  }

  static String lifecycleStageLabel(ProposalLifecycleStage stage) {
    switch (stage) {
      case ProposalLifecycleStage.draft:
        return 'Draft';
      case ProposalLifecycleStage.inReview:
        return 'In Review';
      case ProposalLifecycleStage.released:
        return 'Released';
      case ProposalLifecycleStage.signed:
        return 'Signed';
      case ProposalLifecycleStage.unknown:
        return '—';
    }
  }

  static Color lifecycleStageColor(ProposalLifecycleStage stage) {
    switch (stage) {
      case ProposalLifecycleStage.draft:
        return PremiumTheme.purple;
      case ProposalLifecycleStage.inReview:
        return PremiumTheme.orange;
      case ProposalLifecycleStage.released:
        return PremiumTheme.info;
      case ProposalLifecycleStage.signed:
        return PremiumTheme.teal;
      case ProposalLifecycleStage.unknown:
        return Colors.white70;
    }
  }

  static ProposalApprovalState approvalStateFromStatus(String normalizedStatus) {
    final s = normalizedStatus.trim();

    if (s.contains('changes requested')) {
      return ProposalApprovalState.changesRequested;
    }

    if (s == 'rejected' || s == 'declined' || s == 'lost') {
      return ProposalApprovalState.declined;
    }

    if (s == 'approved' ||
        s == 'signed' ||
        s == 'client signed' ||
        s == 'client approved' ||
        s == 'released' ||
        s == 'sent to client' ||
        s == 'sent for signature' ||
        s.contains('sent to client') ||
        s.contains('sent for signature') ||
        s == 'completed') {
      return ProposalApprovalState.approved;
    }

    if (s.isEmpty || s.contains('draft')) {
      return ProposalApprovalState.readyForApproval;
    }

    if (s.contains('pending') || s.contains('review') || s.contains('submitted')) {
      return ProposalApprovalState.readyForApproval;
    }

    return ProposalApprovalState.unknown;
  }

  static String approvalStateLabel(ProposalApprovalState state) {
    switch (state) {
      case ProposalApprovalState.readyForApproval:
        return 'Ready for approval';
      case ProposalApprovalState.blocked:
        return 'Blocked';
      case ProposalApprovalState.changesRequested:
        return 'Changes requested';
      case ProposalApprovalState.approved:
        return 'Approved';
      case ProposalApprovalState.declined:
        return 'Declined';
      case ProposalApprovalState.unknown:
        return '—';
    }
  }

  static Color approvalStateColor(ProposalApprovalState state) {
    switch (state) {
      case ProposalApprovalState.readyForApproval:
        return PremiumTheme.teal;
      case ProposalApprovalState.blocked:
        return PremiumTheme.orange;
      case ProposalApprovalState.changesRequested:
        return PremiumTheme.pink;
      case ProposalApprovalState.approved:
        return PremiumTheme.teal;
      case ProposalApprovalState.declined:
        return PremiumTheme.error;
      case ProposalApprovalState.unknown:
        return Colors.white70;
    }
  }
}
