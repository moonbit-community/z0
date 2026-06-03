///|
pub struct Options {
  priv mut produce_models : Bool
  priv mut produce_proofs : Bool
  priv mut produce_unsat_cores : Bool
  priv mut produce_unsat_assumptions : Bool
  priv mut global_decls : Bool
  priv mut auto_config : Bool
  priv mut print_success : Bool
  priv mut print_warning : Bool
  priv mut diagnostic_output_channel : String
  priv mut diagnostic_output_channel_explicit : Bool
  priv mut regular_output_channel : String
  priv mut random_seed : Int
  priv mut verbosity : Int
  priv mut numeral_as_real : Bool
  priv mut int_real_coercions : Bool
  priv mut error_behavior : String
  priv mut reproducible_resource_limit : Int?
}

///|
pub fn Options::new() -> Options {
  Options::{
    produce_models: false,
    produce_proofs: false,
    produce_unsat_cores: false,
    produce_unsat_assumptions: false,
    global_decls: false,
    auto_config: false,
    print_success: false,
    print_warning: true,
    diagnostic_output_channel: "stderr",
    diagnostic_output_channel_explicit: false,
    regular_output_channel: "stdout",
    random_seed: 0,
    verbosity: 0,
    numeral_as_real: false,
    int_real_coercions: true,
    error_behavior: "continued-execution",
    reproducible_resource_limit: None,
  }
}

///|
fn parse_bool_option(value : String) -> Bool? {
  match value {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
fn parse_nonnegative_int_option(value : String) -> Int? {
  if value.is_empty() {
    None
  } else {
    let mut result = 0
    for c in value {
      if c < '0' || c > '9' {
        return None
      }
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
    Some(result)
  }
}

///|
fn smt2_quote_option_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for c in value {
    if c == '"' {
      builder.write_string("\\\"")
    } else if c == '\\' {
      builder.write_string("\\\\")
    } else {
      builder.write_char(c)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn bool_option_text(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn valid_error_behavior(value : String) -> Bool {
  value == "continued-execution" || value == "immediate-exit"
}

///|
pub fn Options::set(
  self : Options,
  name : String,
  value : String,
) -> Unit raise {
  match name {
    ":produce-models" =>
      match parse_bool_option(value) {
        Some(parsed) => self.produce_models = parsed
        None =>
          raise @parse_error.ParseError(
            ":produce-models expects true or false",
            None,
          )
      }
    ":produce-proofs" =>
      match parse_bool_option(value) {
        Some(parsed) => self.produce_proofs = parsed
        None =>
          raise @parse_error.ParseError(
            ":produce-proofs expects true or false",
            None,
          )
      }
    ":produce-unsat-cores" =>
      match parse_bool_option(value) {
        Some(parsed) => self.produce_unsat_cores = parsed
        None =>
          raise @parse_error.ParseError(
            ":produce-unsat-cores expects true or false",
            None,
          )
      }
    ":produce-unsat-assumptions" =>
      match parse_bool_option(value) {
        Some(parsed) => self.produce_unsat_assumptions = parsed
        None =>
          raise @parse_error.ParseError(
            ":produce-unsat-assumptions expects true or false",
            None,
          )
      }
    ":global-decls" =>
      match parse_bool_option(value) {
        Some(parsed) => self.global_decls = parsed
        None =>
          raise @parse_error.ParseError(
            ":global-decls expects true or false",
            None,
          )
      }
    ":global-declarations" =>
      match parse_bool_option(value) {
        Some(parsed) => self.global_decls = parsed
        None =>
          raise @parse_error.ParseError(
            ":global-declarations expects true or false",
            None,
          )
      }
    ":auto-config" =>
      match parse_bool_option(value) {
        Some(parsed) => self.auto_config = parsed
        None =>
          raise @parse_error.ParseError(
            ":auto-config expects true or false",
            None,
          )
      }
    ":print-success" =>
      match parse_bool_option(value) {
        Some(parsed) => self.print_success = parsed
        None =>
          raise @parse_error.ParseError(
            ":print-success expects true or false",
            None,
          )
      }
    ":print-warning" =>
      match parse_bool_option(value) {
        Some(parsed) => self.print_warning = parsed
        None =>
          raise @parse_error.ParseError(
            ":print-warning expects true or false",
            None,
          )
      }
    ":numeral-as-real" =>
      match parse_bool_option(value) {
        Some(parsed) => self.numeral_as_real = parsed
        None =>
          raise @parse_error.ParseError(
            ":numeral-as-real expects true or false",
            None,
          )
      }
    ":int-real-coercions" =>
      match parse_bool_option(value) {
        Some(parsed) => self.int_real_coercions = parsed
        None =>
          raise @parse_error.ParseError(
            ":int-real-coercions expects true or false",
            None,
          )
      }
    ":diagnostic-output-channel" => {
      self.diagnostic_output_channel = value
      self.diagnostic_output_channel_explicit = true
    }
    ":regular-output-channel" => self.regular_output_channel = value
    ":random-seed" =>
      match parse_nonnegative_int_option(value) {
        Some(parsed) => self.random_seed = parsed
        None =>
          raise @parse_error.ParseError(
            ":random-seed expects a non-negative integer",
            None,
          )
      }
    ":verbosity" =>
      match parse_nonnegative_int_option(value) {
        Some(parsed) => self.verbosity = parsed
        None =>
          raise @parse_error.ParseError(
            ":verbosity expects a non-negative integer",
            None,
          )
      }
    ":error-behavior" =>
      if valid_error_behavior(value) {
        self.error_behavior = value
      } else {
        raise @parse_error.ParseError(
          ":error-behavior expects continued-execution or immediate-exit",
          None,
        )
      }
    ":reproducible-resource-limit" =>
      match parse_nonnegative_int_option(value) {
        Some(parsed) => self.reproducible_resource_limit = Some(parsed)
        None =>
          raise @parse_error.ParseError(
            ":reproducible-resource-limit expects a non-negative integer",
            None,
          )
      }
    _ =>
      raise @unsupported_error.UnsupportedError(
        "unsupported option: \{name}",
        None,
      )
  }
}

///|
fn Options::value_text(self : Options, name : String) -> String raise {
  match name {
    ":produce-models" => bool_option_text(self.produce_models)
    ":produce-proofs" => bool_option_text(self.produce_proofs)
    ":produce-unsat-cores" => bool_option_text(self.produce_unsat_cores)
    ":produce-unsat-assumptions" =>
      bool_option_text(self.produce_unsat_assumptions)
    ":global-decls" => bool_option_text(self.global_decls)
    ":global-declarations" => bool_option_text(self.global_decls)
    ":auto-config" => bool_option_text(self.auto_config)
    ":print-success" => bool_option_text(self.print_success)
    ":print-warning" => bool_option_text(self.print_warning)
    ":numeral-as-real" => bool_option_text(self.numeral_as_real)
    ":int-real-coercions" => bool_option_text(self.int_real_coercions)
    ":diagnostic-output-channel" =>
      smt2_quote_option_string(self.diagnostic_output_channel)
    ":regular-output-channel" =>
      smt2_quote_option_string(self.regular_output_channel)
    ":random-seed" => "\{self.random_seed}"
    ":verbosity" => "\{self.verbosity}"
    ":error-behavior" => self.error_behavior
    ":reproducible-resource-limit" =>
      match self.reproducible_resource_limit {
        Some(limit) => "\{limit}"
        None => "0"
      }
    _ =>
      raise @unsupported_error.UnsupportedError(
        "unsupported option: \{name}",
        None,
      )
  }
}

///|
pub fn Options::produce_models(self : Options) -> Bool {
  self.produce_models
}

///|
pub fn Options::produce_proofs(self : Options) -> Bool {
  self.produce_proofs
}

///|
pub fn Options::produce_unsat_cores(self : Options) -> Bool {
  self.produce_unsat_cores
}

///|
pub fn Options::produce_unsat_assumptions(self : Options) -> Bool {
  self.produce_unsat_assumptions
}

///|
pub fn Options::global_decls(self : Options) -> Bool {
  self.global_decls
}

///|
pub fn Options::auto_config(self : Options) -> Bool {
  self.auto_config
}

///|
pub fn Options::print_success(self : Options) -> Bool {
  self.print_success
}

///|
fn Options::error_behavior(self : Options) -> String {
  self.error_behavior
}

///|
pub fn Options::diagnostic_output_channel(self : Options) -> String {
  self.diagnostic_output_channel
}

///|
fn Options::diagnostic_output_channel_explicit(self : Options) -> Bool {
  self.diagnostic_output_channel_explicit
}

///|
pub fn Options::regular_output_channel(self : Options) -> String {
  self.regular_output_channel
}

///|
pub fn Options::reproducible_resource_limit(self : Options) -> Int? {
  self.reproducible_resource_limit
}
