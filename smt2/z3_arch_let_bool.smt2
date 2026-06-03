(set-logic QF_UF)
(declare-const p Bool)
(assert (let ((x p)) (and x (not x))))
(check-sat)
