///|
pub struct DependencyConverter {
  priv labels : Array[String]
}

///|
pub fn DependencyConverter::new() -> DependencyConverter {
  { labels: [] }
}

///|
pub fn DependencyConverter::add_label(
  self : DependencyConverter,
  label : String,
) -> Unit {
  self.labels.push(label)
}

///|
pub fn DependencyConverter::labels_text(self : DependencyConverter) -> String {
  self.labels.join(",")
}
