///|
pub fn Tactic::and_then(self : Tactic, next : Tactic) -> Tactic {
  Tactic::new("\{self.name()}>>\{next.name()}", fn(goal) {
    match self.apply(goal) {
      @util.Unavailable(reason) => @util.Unavailable(reason)
      @util.Available(first_result) => {
        let goals : Array[Goal] = []
        for i in 0..<first_result.goal_count() {
          match first_result.goal(i) {
            None => ()
            Some(subgoal) =>
              match next.apply(subgoal) {
                @util.Unavailable(reason) => return @util.Unavailable(reason)
                @util.Available(next_result) =>
                  for j in 0..<next_result.goal_count() {
                    match next_result.goal(j) {
                      Some(next_goal) => goals.push(next_goal)
                      None => ()
                    }
                  }
              }
          }
        }
        @util.Available(TacticResult::from_goals(goals))
      }
    }
  })
}
