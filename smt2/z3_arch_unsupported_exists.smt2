(declare-sort U 0)
(declare-const a U)
(assert (exists ((x U)) (= x a)))
(check-sat)
