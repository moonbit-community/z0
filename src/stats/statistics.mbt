///|
pub(all) enum StatValue {
  Counter(Int32)
  TimerMs(Double)
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend StatValue with Eq::{not_equal, equal}

///|
pub(all) enum StatMergePolicy {
  Sum
  Latest
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend StatMergePolicy with Eq::{not_equal, equal}

///|
pub fn StatMergePolicy::sum() -> StatMergePolicy {
  Sum
}

///|
pub fn StatMergePolicy::latest() -> StatMergePolicy {
  Latest
}

///|
enum StatKind {
  CounterKind
  TimerMsKind
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend StatKind with Eq::{not_equal, equal}

///|
fn StatKind::to_text(self : StatKind) -> String {
  match self {
    CounterKind => "counter"
    TimerMsKind => "timer-ms"
  }
}

///|
priv struct StatDescriptor {
  key : String
  owner : String
  kind : StatKind
  merge_policy : StatMergePolicy
  required_by_phase : String
}

///|
pub struct StatManifest {
  priv descriptors : Array[StatDescriptor]
}

///|
pub fn StatManifest::new() -> StatManifest {
  { descriptors: [], }
}

///|
fn StatDescriptor::matches(
  self : StatDescriptor,
  kind : StatKind,
  owner : String,
  merge_policy : StatMergePolicy,
  required_by_phase : String,
) -> Bool {
  self.kind == kind &&
  self.owner == owner &&
  self.merge_policy == merge_policy &&
  self.required_by_phase == required_by_phase
}

///|
fn StatManifest::find_index(self : StatManifest, key : String) -> Int32 {
  for i in 0..<self.descriptors.length() {
    if self.descriptors[i].key == key {
      return i
    }
  }
  -1
}

///|
fn[T] stat_manifest_unavailable(message : String) -> @util.Availability[T] {
  Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("stat-manifest:\{message}"),
    ),
  )
}

///|
fn StatManifest::add_descriptor(
  self : StatManifest,
  key : String,
  owner : String,
  kind : StatKind,
  merge_policy : StatMergePolicy,
  required_by_phase : String,
) -> @util.Availability[Unit] {
  let index = self.find_index(key)
  if index >= 0 {
    if self.descriptors[index].matches(
        kind, owner, merge_policy, required_by_phase,
      ) {
      Available(())
    } else {
      stat_manifest_unavailable("incompatible-key:\{key}")
    }
  } else {
    self.descriptors.push({ key, owner, kind, merge_policy, required_by_phase, })
    Available(())
  }
}

///|
pub fn StatManifest::add_counter(
  self : StatManifest,
  key : String,
  owner : String,
  merge_policy : StatMergePolicy,
  required_by_phase : String,
) -> @util.Availability[Unit] {
  self.add_descriptor(key, owner, CounterKind, merge_policy, required_by_phase)
}

///|
pub fn StatManifest::add_timer_ms(
  self : StatManifest,
  key : String,
  owner : String,
  merge_policy : StatMergePolicy,
  required_by_phase : String,
) -> @util.Availability[Unit] {
  self.add_descriptor(key, owner, TimerMsKind, merge_policy, required_by_phase)
}

///|
fn StatManifest::find(self : StatManifest, key : String) -> StatDescriptor? {
  let index = self.find_index(key)
  if index >= 0 {
    Some(self.descriptors[index])
  } else {
    None
  }
}

///|
pub fn StatManifest::owner(self : StatManifest, key : String) -> String {
  match self.find(key) {
    Some(descriptor) => descriptor.owner
    None => ""
  }
}

///|
pub fn StatManifest::kind_text(self : StatManifest, key : String) -> String {
  match self.find(key) {
    Some(descriptor) => descriptor.kind.to_text()
    None => "unknown"
  }
}

///|
pub fn StatManifest::keys_text(self : StatManifest) -> String {
  let keys : Array[String] = []
  for descriptor in self.descriptors {
    keys.push(descriptor.key)
  }
  keys.sort_by(compare_strings)
  keys.join(",")
}

///|
priv struct StatEntry {
  key : String
  value : StatValue
}

///|
pub struct Statistics {
  priv entries : Array[StatEntry]
  priv incomplete_reasons : Array[@util.ReasonUnknown]
}

///|
pub fn Statistics::new() -> Statistics {
  { entries: [], incomplete_reasons: [], }
}

///|
fn Statistics::find_index(self : Statistics, key : String) -> Int32 {
  for i in 0..<self.entries.length() {
    if self.entries[i].key == key {
      return i
    }
  }
  -1
}

///|
pub fn Statistics::inc_counter(
  self : Statistics,
  key : String,
  amount : Int32,
) -> Unit {
  let index = self.find_index(key)
  if index >= 0 {
    match self.entries[index].value {
      Counter(value) =>
        self.entries[index] = { key, value: Counter(value + amount), }
      TimerMs(_) => ()
    }
  } else {
    self.entries.push({ key, value: Counter(amount), })
  }
}

///|
pub fn Statistics::add_timer_ms(
  self : Statistics,
  key : String,
  amount : Double,
) -> Unit {
  let index = self.find_index(key)
  if index >= 0 {
    match self.entries[index].value {
      TimerMs(value) =>
        self.entries[index] = { key, value: TimerMs(value + amount), }
      Counter(_) => ()
    }
  } else {
    self.entries.push({ key, value: TimerMs(amount), })
  }
}

///|
fn StatValue::to_text(self : StatValue) -> String {
  match self {
    Counter(value) => "counter:\{value}"
    TimerMs(value) => "timer-ms:\{value}"
  }
}

///|
pub fn Statistics::value_text(self : Statistics, key : String) -> String {
  match self.value(key) {
    Available(value) => value.to_text()
    Unavailable(_) => "missing"
  }
}

///|
pub fn Statistics::value(
  self : Statistics,
  key : String,
) -> @util.Availability[StatValue] {
  let index = self.find_index(key)
  if index >= 0 {
    Available(self.entries[index].value)
  } else {
    Unavailable(
      @util.AvailabilityReason::unsupported(
        @util.ReasonUnknown::unsupported_fragment("unknown-stat:\{key}"),
      ),
    )
  }
}

///|
pub fn Statistics::merge(self : Statistics, other : Statistics) -> Unit {
  for entry in other.entries {
    match entry.value {
      Counter(value) => self.inc_counter(entry.key, value)
      TimerMs(value) => self.add_timer_ms(entry.key, value)
    }
  }
  for reason in other.incomplete_reasons {
    self.mark_incomplete(reason)
  }
}

///|
fn statistics_push_unique_reason(
  reasons : Array[@util.ReasonUnknown],
  reason : @util.ReasonUnknown,
) -> Unit {
  for existing in reasons {
    if existing == reason {
      return
    }
  }
  reasons.push(reason)
}

///|
pub fn Statistics::mark_incomplete(
  self : Statistics,
  reason : @util.ReasonUnknown,
) -> Unit {
  statistics_push_unique_reason(self.incomplete_reasons, reason)
}

///|
pub fn Statistics::incomplete_reasons(
  self : Statistics,
  manifest : StatManifest,
) -> Array[@util.ReasonUnknown] {
  let reasons : Array[@util.ReasonUnknown] = self.incomplete_reasons.copy()
  for entry in self.entries {
    if manifest.find(entry.key) is None {
      statistics_push_unique_reason(
        reasons,
        Other("statistics-missing-owner:\{entry.key}"),
      )
    }
  }
  for descriptor in manifest.descriptors {
    if descriptor.required_by_phase != "" && self.find_index(descriptor.key) < 0 {
      statistics_push_unique_reason(
        reasons,
        Other(
          "statistics-missing-required:\{descriptor.required_by_phase}:\{descriptor.key}",
        ),
      )
    }
  }
  reasons
}

///|
pub fn Statistics::record_solver_check(self : Statistics) -> Unit {
  self.inc_counter("solver.checks", 1)
}

///|
pub fn Statistics::record_model_query(self : Statistics) -> Unit {
  self.inc_counter("model.queries", 1)
}

///|
pub fn Statistics::record_proof_query(self : Statistics) -> Unit {
  self.inc_counter("proof.queries", 1)
}

///|
fn compare_strings(lhs : String, rhs : String) -> Int32 {
  if lhs < rhs {
    -1
  } else if lhs > rhs {
    1
  } else {
    0
  }
}

///|
pub fn Statistics::keys_text(self : Statistics) -> String {
  let keys : Array[String] = []
  for entry in self.entries {
    keys.push(entry.key)
  }
  keys.sort_by(compare_strings)
  let builder = StringBuilder()
  for i in 0..<keys.length() {
    if i > 0 {
      builder.write_char(',')
    }
    builder.write_string(keys[i])
  }
  builder.to_string()
}
