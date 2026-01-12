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
