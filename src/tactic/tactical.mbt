///|
pub fn Tactic::and_then(self : Tactic, next : Tactic) -> Tactic {
  Tactic::new("\{self.name()}>>\{next.name()}", fn(goal) {
    match self.apply(goal) {
      Unavailable(reason) => Unavailable(reason)
      Available(first_result) => {
        let goals : Array[Goal] = []
        for i in 0..<first_result.goal_count() {
          match first_result.goal(i) {
            None => ()
            Some(subgoal) =>
              match next.apply(subgoal) {
                Unavailable(reason) => return Unavailable(reason)
                Available(next_result) =>
                  for j in 0..<next_result.goal_count() {
                    match next_result.goal(j) {
                      Some(next_goal) => goals.push(next_goal)
                      None => ()
                    }
                  }
              }
          }
        }
        Available(TacticResult::from_goals(goals))
      }
    }
  })
}
