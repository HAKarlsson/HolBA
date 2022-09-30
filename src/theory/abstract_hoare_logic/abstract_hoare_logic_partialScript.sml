open HolKernel Parse boolLib bossLib;

open bir_auxiliaryLib;

open bir_auxiliaryTheory;

open abstract_hoare_logicTheory;

val _ = new_theory "abstract_hoare_logic_partial";

val weak_rel_steps_def = Define `
  weak_rel_steps m ms ls ms' n =
          ((n > 0 /\
           FUNPOW_OPT m.trs n ms = SOME ms' /\
           m.pc ms' IN ls) /\
           !n'.
             (n' < n /\ n' > 0 ==>
             ?ms''.
               FUNPOW_OPT m.trs n' ms = SOME ms'' /\
               ~(m.pc ms'' IN ls)
             ))`;

val weak_rel_steps_equiv = prove(``
  !m ms ls ms'.
  weak_model m ==>
  (m.weak ms ls ms' <=>
  ?n. weak_rel_steps m ms ls ms' n)
  ``,

REPEAT STRIP_TAC >>
EQ_TAC >> (
 STRIP_TAC
) >| [
 PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP (fst $ EQ_IMP_RULE (Q.SPEC `m` weak_model_def)) thm]) >>
 Q.EXISTS_TAC `n` >>
 fs [weak_rel_steps_def],

 PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP (fst $ EQ_IMP_RULE (Q.SPEC `m` weak_model_def)) thm]) >>
 fs [weak_rel_steps_def] >>
 Q.EXISTS_TAC `n` >>
 REPEAT STRIP_TAC >> (
  fs []
 )
]
);

val weak_rel_steps_imp = prove(``
  !m ms ls ms' n.
  weak_model m ==>
  (weak_rel_steps m ms ls ms' n ==>
   m.weak ms ls ms')
  ``,

REPEAT STRIP_TAC >>
PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP (fst $ EQ_IMP_RULE (Q.SPEC `m` weak_model_def)) thm]) >>
Q.EXISTS_TAC `n` >>
fs [weak_rel_steps_def]
);

val weak_rel_steps_label = prove(``
  !m ms ls ms' n.
  weak_model m ==>
  weak_rel_steps m ms ls ms' n ==>
  m.pc ms' IN ls
  ``,

fs [weak_rel_steps_def]
);

(* If ms and ms' are not related by weak transition to ls for n transitions,
 * but if taking n transitions from ms takes you to ms' with a label in ls,
 * then there has to exist an ms'' and a *smallest* n' such that the label of
 * ms'' is in ls. *)
val weak_rel_steps_smallest_exists = prove(``
  !m.
  weak_model m ==>
  !ms ls ms' n.
   (* TODO: Only needed for strict inequality *)
   ~(weak_rel_steps m ms ls ms' n) ==>
   n > 0 ==>
   FUNPOW_OPT m.trs n ms = SOME ms' ==>
   m.pc ms' IN ls ==>
   (* TODO: Can be phrased better *)
   ?n' ms''.
    n' < n /\ n' > 0 /\
    FUNPOW_OPT m.trs n' ms = SOME ms'' /\
    m.pc ms'' IN ls /\
    (!n''.
     (n'' < n' /\ n'' > 0 ==>
      ?ms'''. FUNPOW_OPT m.trs n'' ms = SOME ms''' /\
      ~(m.pc ms''' IN ls)))
  ``,

cheat
);

val weak_rel_steps_intermediate_labels = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms' n.
  weak_rel_steps m ms ls1 ms' n ==>
  ~(weak_rel_steps m ms (ls1 UNION ls2) ms' n) ==>
  ?ms'' n'. weak_rel_steps m ms ls2 ms'' n' /\ n' < n
  ``,

REPEAT STRIP_TAC >>
fs [weak_rel_steps_def] >>
rfs [] >>
subgoal `?n' ms''.
  n' < n /\ n' > 0 /\
  FUNPOW_OPT m.trs n' ms = SOME ms'' /\
  (m.pc ms'' IN (ls1 UNION ls2)) /\
  (!n''.
   (n'' < n' /\ n'' > 0 ==>
    ?ms'''. FUNPOW_OPT m.trs n'' ms = SOME ms''' /\
    ~(m.pc ms''' IN (ls1 UNION ls2))))` >- (
 irule weak_rel_steps_smallest_exists >>
 fs [weak_rel_steps_def] >>
 Q.EXISTS_TAC `n'` >>
 REPEAT STRIP_TAC >> (
  fs []
 )
) >>
Q.EXISTS_TAC `ms''` >>
Q.EXISTS_TAC `n''` >>
fs [] >| [
 QSPECL_X_ASSUM ``!(n':num). n' < n /\ n' > 0 ==> _`` [`n''`] >>
 rfs [],

 REPEAT STRIP_TAC >>
 QSPECL_X_ASSUM ``!(n'3':num). n'3' < n'' /\ n'3' > 0 ==> _`` [`n'3'`] >>
 rfs []
]
);

val weak_rel_steps_union = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms' ms'' n n'.
  weak_rel_steps m ms ls1 ms' n ==>
  weak_rel_steps m ms ls2 ms'' n' ==>
  n' < n ==>
  weak_rel_steps m ms (ls1 UNION ls2) ms'' n'
  ``,

REPEAT STRIP_TAC >>
fs [weak_rel_steps_def] >>
REPEAT STRIP_TAC >>
QSPECL_X_ASSUM ``!n'. _`` [`n''`] >>
QSPECL_X_ASSUM ``!n'. _`` [`n''`] >>
rfs [] >>
fs []
);

val weak_intermediate_labels = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms'.
  m.weak ms ls1 ms' ==>
  ~(m.weak ms (ls1 UNION ls2) ms') ==>
  ?ms''. (m.pc ms'') IN ls2 /\ m.weak ms (ls1 UNION ls2) ms''
  ``,

REPEAT STRIP_TAC >>
PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP weak_rel_steps_equiv thm]) >>
QSPECL_X_ASSUM ``!n. _`` [`n`] >>
IMP_RES_TAC weak_rel_steps_intermediate_labels >>
Q.EXISTS_TAC `ms''` >>
CONJ_TAC >| [
 METIS_TAC [weak_rel_steps_label],

 METIS_TAC [weak_rel_steps_union]
]
);

val FUNPOW_ASSOC = prove(``
!f m n x.
FUNPOW f m (FUNPOW f n x) = FUNPOW f n (FUNPOW f m x)``,

fs [GSYM arithmeticTheory.FUNPOW_ADD]
);

val FUNPOW_SUB = prove(``
!f m n x.
m > n ==>
FUNPOW f (m - n) (FUNPOW f n x) = FUNPOW f m x``,

fs [GSYM arithmeticTheory.FUNPOW_ADD]
);

val FUNPOW_OPT_split = prove(``
!f n n' s s' s''.
FUNPOW_OPT f n s = SOME s' ==>
FUNPOW_OPT f (n + n') s = SOME s'' ==>
FUNPOW_OPT f n' s' = SOME s''``,

METIS_TAC [FUNPOW_ASSOC, FUNPOW_OPT_def, arithmeticTheory.FUNPOW_ADD]
);

val FUNPOW_OPT_split2 = prove(``
!f n' n s s'' s'.
n > n' ==>
FUNPOW_OPT f n s = SOME s' ==>
FUNPOW_OPT f n' s = SOME s'' ==>
FUNPOW_OPT f (n - n') s'' = SOME s'``,

REPEAT STRIP_TAC >>
METIS_TAC [FUNPOW_SUB, FUNPOW_OPT_def, arithmeticTheory.FUNPOW_ADD]
);

val weak_rel_steps_unique = prove(``
  !m.
  weak_model m ==>
  !ms ls ms' ms'' n n'.
  weak_rel_steps m ms ls ms' n ==>
  weak_rel_steps m ms ls ms'' n' ==>
  (ms' = ms'' /\ n = n')
  ``,

REPEAT STRIP_TAC >| [
 METIS_TAC [weak_rel_steps_imp, weak_unique_thm],

 fs [weak_rel_steps_def] >>
 CCONTR_TAC >>
 Cases_on `n < n'` >- (
  QSPECL_X_ASSUM ``!n''. _`` [`n`] >>
  rfs []
 ) >>
 QSPECL_X_ASSUM ``!n'.
                  n' < n /\ n' > 0 ==>
                  ?ms''. FUNPOW_OPT m.trs n' ms = SOME ms'' /\ m.pc ms'' NOTIN ls`` [`n'`] >>
 rfs []
]
);

val weak_rel_steps_intermediate_labels2 = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms' ms'' n n'.
  weak_rel_steps m ms ls2 ms' n ==>
  ~(weak_rel_steps m ms (ls1 UNION ls2) ms' n) ==>
  weak_rel_steps m ms (ls1 UNION ls2) ms'' n' ==>
  ?n''. weak_rel_steps m ms'' ls2 ms' n'' /\ n'' < n
  ``,

REPEAT STRIP_TAC >>
subgoal `weak_rel_steps m ms (ls1 UNION ls2) ms'' n' /\ n' < n` >- (
 subgoal `?ms'' n'. weak_rel_steps m ms (ls1 UNION ls2) ms'' n' /\ n' < n` >- (
  METIS_TAC [weak_rel_steps_intermediate_labels, weak_rel_steps_union, pred_setTheory.UNION_COMM]
 ) >>
 METIS_TAC [weak_rel_steps_unique]
) >>
fs [] >>
fs [weak_rel_steps_def] >>
rfs [] >> (
 Q.EXISTS_TAC `n - n'` >>
 subgoal `FUNPOW_OPT m.trs (n - n') ms'' = SOME ms'` >- (
  METIS_TAC [FUNPOW_OPT_split2, arithmeticTheory.GREATER_DEF]
 ) >>
 fs [] >>
 REPEAT STRIP_TAC >>
 QSPECL_X_ASSUM ``!n'.
           n' < n /\ n' > 0 ==>
           ?ms''. FUNPOW_OPT m.trs n' ms = SOME ms'' /\ m.pc ms'' NOTIN ls2`` [`n' + n'3'`] >>
 subgoal `n' + n'3' < n` >- (
  fs []
 ) >>
 subgoal `n' + n'3' > 0` >- (
  fs []
 ) >>
 fs [] >>
 Q.EXISTS_TAC `ms'3'` >>
 fs [] >>
 METIS_TAC [FUNPOW_OPT_split]
)
);

val weak_rel_steps_intermediate_labels3 = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms' ms'' n n'.
  weak_rel_steps m ms ls1 ms' n ==>
  weak_rel_steps m ms (ls2 UNION ls1) ms'' n' ==>
  n' < n ==>
  m.pc ms'' IN ls2
  ``,

cheat
);

val weak_intermediate_labels2 = prove(``
  !m.
  weak_model m ==>
  !ms ls1 ls2 ms' ms''.
  m.weak ms ls2 ms' ==>
  ~(m.weak ms (ls1 UNION ls2) ms') ==>
  m.weak ms (ls1 UNION ls2) ms'' ==>
  m.weak ms'' ls2 ms'
  ``,

REPEAT STRIP_TAC >>
PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP weak_rel_steps_equiv thm]) >>
METIS_TAC [weak_rel_steps_intermediate_labels2]
);

(* Definition of the triple *)
(* Pre and post usually have conditions on execution mode and code in memory *)
(* also post is usually a map that depends on the end state address *)
val abstract_partial_jgmt_def = Define `
  abstract_partial_jgmt m (l:'a) (ls:'a->bool) pre post =
  !ms ms'.
   ((m.pc ms) = l) ==>
   pre ms ==>
   m.weak ms ls ms' ==>
   post ms'
`;

val abstract_jgmt_imp_partial_triple =
  store_thm("abstract_jgmt_imp_partial_triple",
  ``!m l ls pre post.
    weak_model m ==>
    abstract_jgmt m l ls pre post ==>
    abstract_partial_jgmt m l ls pre post``,

FULL_SIMP_TAC std_ss [abstract_jgmt_def, abstract_partial_jgmt_def] >>
REPEAT STRIP_TAC >>
QSPECL_X_ASSUM ``!ms. _`` [`ms`] >>
METIS_TAC [weak_unique_thm]
);

val weak_partial_case_rule_thm = prove(``
!m l ls pre post C1.
  abstract_partial_jgmt m l ls (\ms. (pre ms) /\ (C1 ms)) post ==>
  abstract_partial_jgmt m l ls (\ms. (pre ms) /\ (~(C1 ms))) post ==>
  abstract_partial_jgmt m l ls pre post
``,

REPEAT STRIP_TAC >>
FULL_SIMP_TAC std_ss [abstract_partial_jgmt_def] >>
METIS_TAC []
);

val weak_partial_weakening_rule_thm =
  store_thm("weak_partial_weakening_rule_thm",
  ``!m. 
    !l ls pre1 pre2 post1 post2.
    weak_model m ==>
    (!ms. ((m.pc ms) = l) ==> (pre2 ms) ==> (pre1 ms)) ==>
    (!ms. ((m.pc ms) IN ls) ==> (post1 ms) ==> (post2 ms)) ==>
    abstract_partial_jgmt m l ls pre1 post1 ==>
    abstract_partial_jgmt m l ls pre2 post2
  ``,

SIMP_TAC std_ss [abstract_partial_jgmt_def] >>
REPEAT STRIP_TAC >>
METIS_TAC [weak_pc_in_thm]
);

val weak_partial_subset_rule_thm =
 store_thm("weak_partial_subset_rule_thm",
  ``!m.  ! l ls1 ls2 pre post .
    weak_model m ==>
    (!ms. post ms ==> (~(m.pc ms IN ls2))) ==>
    abstract_partial_jgmt m l (ls1 UNION ls2) pre post ==>
    abstract_partial_jgmt m l ls1 pre post``,

REPEAT STRIP_TAC >>
rfs [abstract_partial_jgmt_def] >>
REPEAT STRIP_TAC >>
QSPECL_ASSUM ``!ms ms'. _`` [`ms`, `ms'`] >>
rfs [] >>
Cases_on `m.weak ms (ls1 UNION ls2) ms'` >- (
 fs []
) >>
subgoal `?n. FUNPOW_OPT m.trs n ms = SOME ms'` >- (
 METIS_TAC [weak_model_def]
) >>
IMP_RES_TAC weak_intermediate_labels >>
QSPECL_X_ASSUM ``!ms ms'. _`` [`ms`, `ms''`] >>
rfs [] >>
METIS_TAC []
);


val weak_partial_conj_rule_thm = prove(``
  !m.
  weak_model m ==>
  !l ls pre post1 post2.
  abstract_partial_jgmt m l ls pre post1 ==>
  abstract_partial_jgmt m l ls pre post2 ==>
  abstract_partial_jgmt m l ls pre (\ms. (post1 ms) /\ (post2 ms))``,

REPEAT STRIP_TAC >>
FULL_SIMP_TAC std_ss [abstract_partial_jgmt_def] >>
REPEAT STRIP_TAC >>
METIS_TAC [weak_unique_thm]
);

(* TODO: This is introduced since negating m.weak gets weird *)
(* TODO: Still needed? *)
val trs_in_lblset_def = Define `
  trs_in_lblset m ms n ls =
    let
      ms'_opt = FUNPOW_OPT m.trs n ms
    in
    if IS_NONE ms'_opt
    then F
    else if m.pc (THE ms'_opt) IN ls
         then T
         else F
`;

val weak_partial_seq_rule_thm = store_thm("weak_partial_seq_rule_thm",
  ``!m l ls1 ls2 pre post.
    weak_model m ==>
    abstract_partial_jgmt m l (ls1 UNION ls2) pre post ==>
    (!l1. (l1 IN ls1) ==>
    (abstract_partial_jgmt m l1 ls2 post post)) ==>
    abstract_partial_jgmt m l ls2 pre post``,

REPEAT STRIP_TAC >>
FULL_SIMP_TAC std_ss [abstract_partial_jgmt_def] >>
REPEAT STRIP_TAC >>
QSPECL_X_ASSUM ``!ms ms'.
		 (m.pc ms = l) ==>
		 pre ms ==>
		 m.weak ms (ls1 UNION ls2) ms' ==>
		 post ms'`` [`ms`] >>
rfs [] >>
subgoal `(m.pc ms') IN ls2` >- (
  METIS_TAC [weak_pc_in_thm]
) >>
Cases_on `m.weak ms (ls1 UNION ls2) ms'` >- (
  METIS_TAC []
) >>
subgoal `?ms''. m.pc ms'' IN ls1 /\ m.weak ms (ls2 UNION ls1) ms''` >- (
  METIS_TAC [weak_intermediate_labels, pred_setTheory.UNION_COMM]
) >>
QSPECL_X_ASSUM  ``!l1. l1 IN ls1 ==> _`` [`m.pc ms''`] >>
rfs [] >>
QSPECL_X_ASSUM  ``!ms ms'. _`` [`ms''`, `ms'`] >>
rfs [] >>
subgoal `post ms''` >- (
  METIS_TAC [pred_setTheory.UNION_COMM]
) >>
METIS_TAC [pred_setTheory.UNION_COMM, weak_intermediate_labels2]
);


val weak_rel_steps_list_states = prove(``
!m ms l ls ms' n.
 weak_model m ==>
 weak_rel_steps m ms ls ms' n ==>
 ?ms_list.
  (LENGTH ms_list = 0 ==> weak_rel_steps m ms ({l} UNION ls) ms' n) /\
  (LENGTH ms_list > 0 ==>
  !i. (?n'. weak_rel_steps m ms ({l} UNION ls) (HD ms_list) n' /\ n' < n /\ n' > 0) /\
      (i < ((LENGTH ms_list) - 1) ==> ?n'.
       weak_rel_steps m (EL i ms_list) ({l} UNION ls) (EL (i+1) ms_list) n' /\ n' < n /\ n' > 0) /\
      ?n''. weak_rel_steps m (EL ((LENGTH ms_list) - 1) ms_list) ({l} UNION ls) ms' n'' /\ n'' > 0)
``,

cheat
);

(* OLD
val weak_list_states = prove(``
!m ms l ls ms'.
 weak_model m ==>
 weak ms ls ms' ==>
 ?ms_list.
  (LENGTH ms_list = 0 ==> m.weak ms ({l} UNION ls) ms') /\
  (LENGTH ms_list > 0 ==>
  !i. (i = 0 ==> m.weak ms ({l} UNION ls) (EL i ms_list) /\
                 m.weak (EL i ms_list) ({l} UNION ls) ms') /\
      (i > 0 /\ i < ((LENGTH ms_list) - 1) ==>
       m.weak (EL i ms_list) ({l} UNION ls) (EL (i+1) ms_list)) /\
      m.weak (EL ((LENGTH ms_list) - 1) ms_list) ({l} UNION ls) ms')
``,

cheat
);
*)

val weak_partial_loop_contract_def = Define `
  weak_partial_loop_contract m l le invariant C1 =
    (l NOTIN le /\
     abstract_partial_jgmt m l ({l} UNION le) (\ms. invariant ms /\ C1 ms)
       (\ms. m.pc ms = l /\ invariant ms))
`;
(* TODO: Preliminaries for proving partial loop rule *)
val weak_partial_loop_rule_thm = store_thm("weak_partial_loop_rule_thm",
  ``!m.
    weak_model m ==>
    !l le invariant C1 var post.
    weak_partial_loop_contract m l le invariant C1 ==>
    abstract_partial_jgmt m l le (\ms. invariant ms /\ ~(C1 ms)) post ==>
    abstract_partial_jgmt m l le invariant post``,

REPEAT STRIP_TAC >>
fs [abstract_partial_jgmt_def, weak_partial_loop_contract_def] >>
REPEAT STRIP_TAC >>
PAT_ASSUM ``weak_model m`` (fn thm => fs [HO_MATCH_MP weak_rel_steps_equiv thm]) >>
IMP_RES_TAC weak_rel_steps_list_states >>
QSPECL_X_ASSUM  ``!l. ?ms_list. _`` [`l`] >>
fs [] >>
Cases_on `ms_list = []` >- (
 fs [] >>
 QSPECL_X_ASSUM  ``!ms ms'. _`` [`ms`, `ms'`] >>
 QSPECL_X_ASSUM  ``!ms ms'. _`` [`ms`, `ms'`] >>
 rfs [] >>
 Cases_on `C1 ms` >| [
  METIS_TAC [weak_pc_in_thm, weak_rel_steps_imp],

  METIS_TAC []
 ]
) >>
subgoal `LENGTH ms_list > 0` >- (
 fs [listTheory.NOT_NIL_EQ_LENGTH_NOT_0]
) >>
fs [] >>
Cases_on `~C1 ms` >- (
 cheat
) >>
fs [] >>
(* TODO: Fill this out *)
subgoal `!i. i < LENGTH ms_list ==> m.pc (EL i ms_list) = l /\ invariant (EL i ms_list)` >- (
 Induct_on `i` >- (
  REPEAT STRIP_TAC >> (
   fs [] >>
   QSPECL_X_ASSUM  ``!i. _`` [`0`] >>
   fs [] >>
   METIS_TAC [weak_rel_steps_intermediate_labels3, pred_setTheory.IN_SING]
  )
 ) >>
 REPEAT STRIP_TAC >> (
  fs []
 ) >> (
  QSPECL_X_ASSUM  ``!i. _`` [`i`] >>
  fs [] >>
  rfs [] >>
  QSPECL_X_ASSUM  ``!ms ms'. _`` [`EL i ms_list`, `EL (SUC i) ms_list`] >>
  QSPECL_X_ASSUM  ``!ms ms'. _`` [`EL i ms_list`, `EL (SUC i) ms_list`] >>
  rfs [] >>
  subgoal `!i. i < LENGTH ms_list - 1 ==> C1 (EL i ms_list)` >- (
   cheat
  ) >>
  QSPECL_X_ASSUM  ``!i. _`` [`i`] >>
  rfs [] >>
  fs [] >>
  `?n. weak_rel_steps m (EL i ms_list) ({l} UNION le) (EL (SUC i) ms_list) n` suffices_by (
   fs []
  ) >>
  Q.EXISTS_TAC `n'3'` >>
  fs [arithmeticTheory.SUC_ONE_ADD]
 )
) >>
QSPECL_X_ASSUM  ``!ms ms'. _`` [`EL (LENGTH ms_list − 1) ms_list`, `ms'`] >>
QSPECL_X_ASSUM  ``!ms ms'. _`` [`EL (LENGTH ms_list − 1) ms_list`, `ms'`] >>
subgoal `MEM (EL (LENGTH ms_list − 1) ms_list) ms_list` >- (
 subgoal `LENGTH ms_list − 1 < LENGTH ms_list` >- (
  fs [listTheory.NOT_NIL_EQ_LENGTH_NOT_0]
 ) >>
 METIS_TAC [rich_listTheory.EL_MEM]
) >>
rfs [] >>
Cases_on `C1 (EL (LENGTH ms_list − 1) ms_list)` >| [
 fs [] >>
 QSPECL_X_ASSUM  ``!i. _`` [`LENGTH ms_list − 1`] >>
 fs [] >>
 METIS_TAC [weak_pc_in_thm, weak_rel_steps_imp],

 subgoal `m.pc ms' <> l` >- (
   METIS_TAC [weak_pc_in_thm, weak_rel_steps_imp]
 ) >>
 fs [] >>
 QSPECL_X_ASSUM  ``!i. A /\ B`` [`LENGTH ms_list − 1`] >>
 fs [] >>
 `?n. weak_rel_steps m (EL (LENGTH ms_list − 1) ms_list) le ms' n` suffices_by (
  fs []
 ) >>
 subgoal `m.weak (EL (LENGTH ms_list − 1) ms_list) ({l} UNION le) ms'` >- (
  METIS_TAC [weak_rel_steps_imp]
 ) >>
 PAT_ASSUM ``weak_model m`` (fn thm => fs [GSYM (HO_MATCH_MP weak_rel_steps_equiv thm)]) >>
 irule weak_union_pc_not_in_thm >>
 fs [] >>
 Q.EXISTS_TAC `{l}` >>
 fs [pred_setTheory.UNION_COMM]
]
);

val _ = export_theory();
