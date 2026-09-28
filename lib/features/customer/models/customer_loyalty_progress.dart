/// Reconocimientos informativos basados en servicios pagados confirmados.
class CustomerLoyaltyProgress {
  final int paidServices;

  const CustomerLoyaltyProgress(this.paidServices);

  String get level {
    if (paidServices >= 10) return 'Cliente habitual';
    if (paidServices >= 3) return 'Cliente recurrente';
    return 'Primeros servicios';
  }

  int? get nextGoal {
    if (paidServices >= 10) return null;
    return paidServices >= 3 ? 10 : 3;
  }

  int? get remaining {
    final goal = nextGoal;
    return goal == null ? null : goal - paidServices;
  }

  double? get progress {
    final goal = nextGoal;
    return goal == null ? null : paidServices / goal;
  }
}
