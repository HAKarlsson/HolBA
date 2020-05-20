open HolKernel Parse boolLib bossLib;

open bir_wm_instTheory;

open tutorialExtra_wpTheory;
open tutorialExtra_smtTheory;

open tutorial_wpSupportLib;
open tutorial_compositionLib;

val _ = new_theory "tutorialExtra_composition";

(* For debugging:
val (get_labels_from_set_repr, el_in_set_repr,
     mk_set_repr, simp_delete_set_repr_rule,
     simp_insert_set_repr_rule, simp_in_sing_set_repr_rule, simp_inter_set_repr_rule, simp_in_set_repr_tac, inter_set_repr_ss, union_set_repr_ss) = (ending_set_to_sml_list, el_in_set, mk_set, simp_delete_set_rule,
     simp_insert_set_rule, simp_in_sing_set_rule, simp_inter_set_rule, simp_in_set_tac, bir_inter_var_set_ss, bir_union_var_set_ss);
*)

(* TODO: in composition function, make conditional "return" jump work *)
(* TODO: enable usage of variable blacklist set with assumptions -> bigger compositional reasoning *)

fun try_disch_all_assump_w_EVAL t =
  let
    val t_d      = DISCH_ALL t;
    val assum_tm = (fst o dest_imp o concl) t_d;
    val t_as     = EVAL assum_tm;
    val t2       = REWRITE_RULE [t_as] (DISCH assum_tm t)
  in
    try_disch_all_assump_w_EVAL t2
  end
  handle HOL_ERR _ => t;

(* Turn the contracts generated by WP tool into compositional ones *)

(* TODO: Make label_ct_to_map_ct_predset_assmpt *)
val att_sec_add_assmpt = ``((v3:word32) <> 260w) /\ ((v4:word32) <> 260w) /\ (v4 <> v3)``;
val bir_att_sec_add_1_comp_ht =
  bir_populate_blacklist_assmpt (ending_set_to_sml_list, el_in_set, mk_set,
                                 simp_delete_set_rule, simp_insert_set_rule)
    (bir_map_triple_from_bir_triple
      (use_pre_str_rule
        (HO_MATCH_MP bir_label_ht_impl_weak_ht
          (bir_att_sec_add_1_ht)
        ) contract_1_imp_taut_thm
      )
    ) att_sec_add_assmpt;


val bir_att_sec_add_2_comp_ht =
  bir_populate_blacklist_assmpt (ending_set_to_sml_list, el_in_set, mk_set,
                                 simp_delete_set_rule, simp_insert_set_rule)
    (bir_map_triple_from_bir_triple
      (HO_MATCH_MP bir_label_ht_impl_weak_ht
        ((UNDISCH o UNDISCH o (Q.SPECL [`v1`, `v2`, `v3`, `v4`])) bir_att_sec_add_2_ht)
      )
    ) att_sec_add_assmpt;

val bir_att_sec_call_1_comp_ht =
  label_ct_to_map_ct_predset bir_att_sec_call_1_ht contract_2_imp_taut_thm;

val bir_att_sec_call_2_comp_ht =
  label_ct_to_map_ct_predset bir_att_sec_call_2_ht contract_3_imp_taut_thm;

val def_list = [bir_att_sec_add_2_post_def,
		bir_att_sec_add_1_post_def];


(* ====================================== *)
(* ADD function *)

(* For debugging:
  val map_ht1 = bir_att_sec_add_1_comp_ht
  val map_ht2 = bir_att_sec_add_2_comp_ht
  val assmpt = att_sec_add_assmpt
*)
val bir_att_sec_add_ht =
  bir_compose_seq_assmpt_predset
    bir_att_sec_add_1_comp_ht
    bir_att_sec_add_2_comp_ht
    def_list att_sec_add_assmpt;


(* ====================================== *)
(* call 1 *)
val bir_att_sec_add_0x4_ht =
  (try_disch_all_assump_w_EVAL o
    ((INST [``v3:word32`` |-> ``0x004w:word32``,
	    ``v4:word32`` |-> ``0x008w:word32``]))
  ) bir_att_sec_add_ht;

val bir_att_sec_call_1_comp_map_ht =
  REWRITE_RULE [(EVAL THENC
                  (REWRITE_CONV [GSYM (EVAL ``bir_att_sec_add_1_pre v1 v2 4w``)])
                ) ``bir_att_sec_call_1_post v1 v2``]
               bir_att_sec_call_1_comp_ht;

val bir_att_sec_call_1_map_ht =
  bir_compose_seq_predset
    bir_att_sec_call_1_comp_map_ht
    bir_att_sec_add_0x4_ht
    def_list;


(* ====================================== *)
(* call 2 *)
(* introduce dummy address 0x200 (hack for simplification) *)
val bir_att_sec_add_0x8_ht =
  (try_disch_all_assump_w_EVAL o
    ((INST [``v3:word32`` |-> ``0x008w:word32``,
	    ``v4:word32`` |-> ``0x200w:word32``,
	    ``v2:word32`` |-> ``v1:word32``]))
  ) bir_att_sec_add_ht;

val bir_att_sec_call_2_comp_map_ht =
  REWRITE_RULE [(EVAL THENC
                  (REWRITE_CONV [GSYM (EVAL ``bir_att_sec_add_1_pre v1 v1 8w``)])
                ) ``bir_att_sec_call_2_post v1``]
               bir_att_sec_call_2_comp_ht;

val bir_att_sec_call_2_map_ht =
  bir_compose_seq_predset
    bir_att_sec_call_2_comp_map_ht
    bir_att_sec_add_0x8_ht
    def_list;


(* ====================================== *)
(* composition of the function body *)
local
open tutorial_smtSupportLib;
in
val bir_att_sec_call_1_taut =
  ((*(Q.SPECL [`v2`, `v1`]) o *) prove_exp_is_taut)
    (bimp (``bir_att_sec_add_2_post v1 v2``,
           ``bir_att_sec_call_2_pre (v1+v2)``)
  );
end

val bir_att_sec_call_1_map_ht_fix =
  bir_att_sec_call_1_map_ht;

val bir_att_sec_call_2_map_ht_inst =
  (INST [``v1:word32`` |-> ``(v1:word32) + (v2:word32)``])
    bir_att_sec_call_2_map_ht;

val bir_att_sec_call_2_map_ht_fix =
  use_pre_str_rule_map
    bir_att_sec_call_2_map_ht_inst
    bir_att_sec_call_1_taut;

val bir_att_body_map_ht =
  bir_compose_seq_predset
    bir_att_sec_call_1_map_ht_fix
    bir_att_sec_call_2_map_ht_fix
    def_list;

(* experiment with postcondition weakening *)
val map_ht_thm =     bir_att_sec_call_1_map_ht
val post1_impl_post2 =    bir_att_sec_call_1_taut;
val l2 = ``BL_Address (Imm32 4w)``;

val bir_att_sec_call_1_map_ht_alt =
  use_post_weak_rule_map map_ht_thm l2 post1_impl_post2;

val bir_att_body_map_ht_alt =
  bir_compose_seq_predset
    bir_att_sec_call_1_map_ht_alt
    bir_att_sec_call_2_map_ht_inst
    def_list;

val _ =
  if concl bir_att_body_map_ht_alt = concl bir_att_body_map_ht
  then ()
  else
    raise ERR "composition of example code" "composition using two types of contract weakening does not give the same result";


(* ====================================== *)
(* final composition, needs postcondition weakening *)
local
open tutorial_smtSupportLib;
in
val bir_att_post_taut = prove_exp_is_taut
  (bimp (``bir_att_sec_add_2_post (v1 + v2) (v1 + v2)``,
         ``bir_att_sec_2_post v1 v2``)
  );
end

val bir_att_post_ht =
  use_post_weak_rule_map
    bir_att_body_map_ht_alt
    ``BL_Address (Imm32 8w)``
    bir_att_post_taut;


(* ====================================== *)
(* store theorem after final composition *)
val bir_att_ht = save_thm("bir_att_ht",
  REWRITE_RULE [bir_att_sec_2_post_def, bir_att_sec_call_1_pre_def]
    bir_att_post_ht
);

val _ = export_theory();

