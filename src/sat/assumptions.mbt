///|
pub(all) struct AssumptionCore {
  literals : Array[Literal]
} derive(Eq)

///|
pub fn AssumptionCore::text(self : AssumptionCore) -> String {
  "\{Clause::new(self.literals)}"
}

///|
pub fn AssumptionCore::literals(self : AssumptionCore) -> Array[Literal] {
  self.literals.copy()
}

///|
pub(all) enum AssumptionCheckResult {
  AssumptionSat(SatCoreModel)
  AssumptionUnsat(AssumptionCore)
  AssumptionUnknown(String)
} derive(Eq)
