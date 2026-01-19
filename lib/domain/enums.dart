enum MatchMode {
  oneVOne,
  twoVTwo,
}

extension MatchModeJson on MatchMode {
  String toJson() => this == MatchMode.oneVOne ? '1V1' : '2V2';

  static MatchMode fromJson(String value) {
    return value == '2V2' ? MatchMode.twoVTwo : MatchMode.oneVOne;
  }
}

enum MatchResult {
  a,
  b,
  draw,
}

extension MatchResultJson on MatchResult {
  String toJson() {
    switch (this) {
      case MatchResult.a:
        return 'A';
      case MatchResult.b:
        return 'B';
      case MatchResult.draw:
        return 'DRAW';
    }
  }

  static MatchResult fromJson(String value) {
    switch (value) {
      case 'A':
        return MatchResult.a;
      case 'B':
        return MatchResult.b;
      default:
        return MatchResult.draw;
    }
  }
}

enum MatchRatingMode {
  friendly,
  ranked,
  tournament,
}

extension MatchRatingModeJson on MatchRatingMode {
  String toJson() {
    switch (this) {
      case MatchRatingMode.friendly:
        return 'FRIENDLY';
      case MatchRatingMode.tournament:
        return 'TOURNAMENT';
      case MatchRatingMode.ranked:
      default:
        return 'RANKED';
    }
  }

  static MatchRatingMode fromJson(String value) {
    switch (value) {
      case 'FRIENDLY':
        return MatchRatingMode.friendly;
      case 'TOURNAMENT':
        return MatchRatingMode.tournament;
      default:
        return MatchRatingMode.ranked;
    }
  }

  double defaultMultiplier() {
    switch (this) {
      case MatchRatingMode.friendly:
        return 0.5;
      case MatchRatingMode.tournament:
        return 1.2;
      case MatchRatingMode.ranked:
      default:
        return 1.0;
    }
  }
}

enum TournamentStatus {
  draft,
  group,
  finalStage,
  completed,
}

extension TournamentStatusJson on TournamentStatus {
  String toJson() {
    switch (this) {
      case TournamentStatus.draft:
        return 'DRAFT';
      case TournamentStatus.group:
        return 'GROUP';
      case TournamentStatus.finalStage:
        return 'FINAL';
      case TournamentStatus.completed:
        return 'COMPLETED';
    }
  }

  static TournamentStatus fromJson(String value) {
    switch (value) {
      case 'GROUP':
        return TournamentStatus.group;
      case 'FINAL':
        return TournamentStatus.finalStage;
      case 'COMPLETED':
        return TournamentStatus.completed;
      default:
        return TournamentStatus.draft;
    }
  }
}

enum TournamentStage {
  group,
  finalStage,
}

extension TournamentStageJson on TournamentStage {
  String toJson() => this == TournamentStage.group ? 'GROUP' : 'FINAL';

  static TournamentStage fromJson(String value) {
    return value == 'FINAL' ? TournamentStage.finalStage : TournamentStage.group;
  }
}

enum TournamentMatchStatus {
  scheduled,
  done,
  cancelled,
}

extension TournamentMatchStatusJson on TournamentMatchStatus {
  String toJson() {
    switch (this) {
      case TournamentMatchStatus.done:
        return 'DONE';
      case TournamentMatchStatus.cancelled:
        return 'CANCELLED';
      default:
        return 'SCHEDULED';
    }
  }

  static TournamentMatchStatus fromJson(String value) {
    switch (value) {
      case 'DONE':
        return TournamentMatchStatus.done;
      case 'CANCELLED':
        return TournamentMatchStatus.cancelled;
      default:
        return TournamentMatchStatus.scheduled;
    }
  }
}

enum SeasonType {
  month,
  quarter,
  year,
}

extension SeasonTypeJson on SeasonType {
  String toJson() {
    switch (this) {
      case SeasonType.quarter:
        return 'QUARTER';
      case SeasonType.year:
        return 'YEAR';
      case SeasonType.month:
      default:
        return 'MONTH';
    }
  }

  static SeasonType fromJson(String value) {
    switch (value) {
      case 'QUARTER':
        return SeasonType.quarter;
      case 'YEAR':
        return SeasonType.year;
      default:
        return SeasonType.month;
    }
  }
}

enum SeasonResetPolicy {
  none,
  hardReset,
  softReset,
}

extension SeasonResetPolicyJson on SeasonResetPolicy {
  String toJson() {
    switch (this) {
      case SeasonResetPolicy.hardReset:
        return 'HARD_RESET';
      case SeasonResetPolicy.softReset:
        return 'SOFT_RESET';
      case SeasonResetPolicy.none:
      default:
        return 'NONE';
    }
  }

  static SeasonResetPolicy fromJson(String value) {
    switch (value) {
      case 'HARD_RESET':
        return SeasonResetPolicy.hardReset;
      case 'SOFT_RESET':
        return SeasonResetPolicy.softReset;
      default:
        return SeasonResetPolicy.none;
    }
  }
}

enum ClubAssignmentMode {
  auto,
  manual,
}

extension ClubAssignmentModeJson on ClubAssignmentMode {
  String toJson() {
    switch (this) {
      case ClubAssignmentMode.manual:
        return 'MANUAL';
      case ClubAssignmentMode.auto:
      default:
        return 'AUTO';
    }
  }

  static ClubAssignmentMode fromJson(String value) {
    switch (value) {
      case 'MANUAL':
        return ClubAssignmentMode.manual;
      case 'AUTO':
      default:
        return ClubAssignmentMode.auto;
    }
  }
}
