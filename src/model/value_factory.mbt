///|
pub struct ModelValue {
  priv sort : @util.SortId?
  priv text : String
  priv int_value : Int?
  priv universe_member : Bool
}

///|
pub fn ModelValue::bool(value : Bool) -> ModelValue {
  {
    sort: None,
    text: if value {
      "true"
    } else {
      "false"
    },
    int_value: None,
    universe_member: false,
  }
}

///|
pub fn ModelValue::int(value : Int) -> ModelValue {
  {
    sort: None,
    text: value.to_string(),
    int_value: Some(value),
    universe_member: false,
  }
}

///|
fn ModelValue::uninterpreted(sort : @util.SortId, text : String) -> ModelValue {
  { sort: Some(sort), text, int_value: None, universe_member: true }
}

///|
fn ModelValue::raw(text : String) -> ModelValue {
  { sort: None, text, int_value: None, universe_member: false }
}

///|
pub fn ModelValue::to_text(self : ModelValue) -> String {
  self.text
}

///|
pub fn ModelValue::sort(self : ModelValue) -> @util.SortId? {
  self.sort
}

///|
fn ModelValue::is_universe_member(self : ModelValue) -> Bool {
  self.universe_member
}

///|
fn parse_model_int_text(text : String) -> Int? {
  if text.is_empty() {
    return None
  }
  let mut sign = 1
  let mut seen_digit = false
  let mut value = 0
  for i, c in text {
    if i == 0 && c == '-' {
      sign = -1
    } else if c < '0' || c > '9' {
      return None
    } else {
      seen_digit = true
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
  }
  if seen_digit {
    Some(sign * value)
  } else {
    None
  }
}

///|
fn ModelValue::as_int(self : ModelValue) -> Int? {
  match self.int_value {
    Some(value) => Some(value)
    None => parse_model_int_text(self.text)
  }
}

///|
struct SortValueCounter {
  sort : @util.SortId
  next : Int
}

///|
pub struct ValueFactory {
  priv counters : Array[SortValueCounter]
}

///|
pub fn ValueFactory::new() -> ValueFactory {
  { counters: [] }
}

///|
pub fn ValueFactory::fresh_uninterpreted(
  self : ValueFactory,
  sort : @util.SortId,
  sort_name : String,
) -> ModelValue {
  for i, counter in self.counters {
    if counter.sort == sort {
      self.counters[i] = { sort, next: counter.next + 1 }
      return ModelValue::uninterpreted(sort, "@\{sort_name}\{counter.next}")
    }
  }
  self.counters.push({ sort, next: 1 })
  ModelValue::uninterpreted(sort, "@\{sort_name}0")
}
