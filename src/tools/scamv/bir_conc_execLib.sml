structure bir_conc_execLib : bir_conc_execLib =
struct
(* HOL_Interactive.toggle_quietdec(); *)

  open HolKernel pairLib listSyntax stringSyntax wordsSyntax optionSyntax;
  open bir_symb_execLib;
  open bir_symb_masterLib;
  open bir_symb_init_envLib;     
  open bir_embexp_driverLib;
(* HOL_Interactive.toggle_quietdec(); *)


  val EVAL_CONV =
      computeLib.compset_conv (reduceLib.num_compset())
			      [computeLib.Defs
				   [pred_setTheory.NOT_IN_EMPTY, pred_setTheory.IN_INSERT,
				    REWRITE_RULE [GSYM arithmeticTheory.DIV2_def] wordsTheory.BIT_SET_def,
				    listTheory.EVERY_DEF, listTheory.FOLDL,
				    numLib.SUC_RULE rich_listTheory.COUNT_LIST_AUX_def,
				    GSYM rich_listTheory.COUNT_LIST_GENLIST,
				    rich_listTheory.COUNT_LIST_compute,
				    numeral_bitTheory.numeral_log2, numeral_bitTheory.numeral_ilog2,
				    numeral_bitTheory.LOG_compute, GSYM DISJ_ASSOC],
			       computeLib.Convs
				   [(``fcp$dimindex:'a itself -> num``, 1, wordsLib.SIZES_CONV),
				    (``words$word_mod:'a word -> 'a word -> 'a word``, 2,
				     wordsLib.WORD_MOD_BITS_CONV)]];


  fun update_env name value env = 
      let
        val hname = fromMLstring name
        val wordval = mk_wordi (value, 64);
      in
	  (rhs o concl o EVAL) `` bir_symb_env_update 
			  ^hname (BExp_Const (Imm64 ^wordval)) (BType_Imm Bit64) ^env
			  ``
      end;

  fun gen_symb_updates s env =
    foldr (fn ((n,v),e) => update_env n v e) (env) s;

  fun econcl exp = (rhs o concl o EVAL) exp
  val toTerm = rhs o concl

  fun mem_init_conc_exec exp [] =
      let 
	  open bir_expSyntax
	  open bir_immSyntax
	  open bir_valuesSyntax
	  open bir_exp_substitutionsSyntax
	  fun distinct [] = []
	    | distinct (x::xs) = x::distinct(List.filter (fn y => y <> x) xs);

	  val mem = mk_var ("MEM",Type`:num |-> num`)
	  val loadList = find_terms is_BExp_Load (econcl exp)
	  val addrList = map (fn ldexp => 
				 let
				     val (_, a, _, _) = dest_BExp_Load ldexp
				     val addr = case (find_terms is_BExp_Load a) of
					 [] => a
					 | _ => 
					   let
					       val (_, a', _, _) = dest_BExp_Load ((hd o find_terms is_BExp_Load) a) 
					   in 
					       a'
					   end
				 in
				     econcl ``bir_eval_exp ^addr (BEnv (K NONE))``
				 end) loadList;

	  val memLocInit = map (fn waddr => 
				   let
				       val wa = ( snd o gen_dest_Imm o dest_BVal_Imm) ((snd o dest_comb) waddr) 
				       val na = (econcl ``w2n ^wa``)
				   in
				       [``(^na, 0:num)``, ``(^na+1, 0:num)``, ``(^na+2, 0:num)``, ``(^na+3, 0:num)``]
				   end) (distinct addrList)

	  val evalMemLocAddr = map (fn el => econcl el ) (flatten memLocInit);
	  val memInit = foldl (fn (x,y) => ``^y |+ ^x``) ``(FEMPTY: num |-> num)`` evalMemLocAddr
	  val memSubs = subst [mem |-> memInit] (econcl exp)
      in
	  memSubs
      end
    | mem_init_conc_exec exp xs =
      let open numSyntax
	  open Arbnum
	  val val_pairt = map (fn (a,b) => ( mk_pair((term_of_int o toInt) a, (term_of_int o toInt) b))) xs

	  val mem = mk_var ("MEM",Type`:num |-> num`);
	  val memInit = foldl (fn (x,y) => ``^y |+ ^x``) ``(FEMPTY: num |-> num)`` val_pairt
	  val memSubs = subst [mem |-> memInit] (econcl exp)
      in
	  memSubs
      end

  fun syntax_fns n d m = HolKernel.syntax_fns {n = n, dest = d, make = m} "bir_exp_mem";
  val syntax_fns6 = syntax_fns 6 dest_sexop mk_sexop;
  val (bir_load_from_mem_tm,  mk_bir_load_from_mem, dest_bir_load_from_mem, is_bir_load_from_mem)  =
      (syntax_fns6 ) "bir_load_from_mem";

  fun load_store_simp_tac tm =
      let 
	  open bir_exp_memTheory
	  open bir_exec_expLib

	  val (_,mmp,a,_) = dest_bir_update_mmap ( find_term is_bir_update_mmap tm);
	  val (vty,aty,_,_,en,addr) = (dest_bir_load_from_mem) (find_term is_bir_load_from_mem tm)
	  val tm' = SIMP_RULE ((std_ss++HolBACoreSimps.holBACore_ss)) [bir_store_in_mem_def, LET_DEF]
          (ISPECL[a, en, vty, aty, ``(Imm64 (dummy :word64))``, mmp] bir_store_in_mem_used_addrs_THM)
	  val res = (toTerm o EVAL_CONV) (concl (SIMP_RULE (arith_ss) [] (SPECL[addr] tm')))
      in
	  res
      end

  fun load_store_simp_tac1 tm =
      let
	  open bir_exp_memTheory
	  open bir_exec_expLib
      in
	  ((#2 o dest_eq o toTerm) o (SIMP_CONV (std_ss) [bir_mem_addr_def, bitTheory.MOD_2EXP_def, size_of_bir_immtype_def]) 
	   o load_store_simp_tac
	   o toTerm o SIMP_RULE (std_ss++HolBACoreSimps.bir_load_store_ss) []
	   o (computeLib.RESTR_EVAL_RULE [``bir_eval_load``, ``bir_eval_store``]) 
	   o SIMP_CONV(std_ss++HolBACoreSimps.bir_load_store_ss) [bir_eval_load_def, bir_eval_store_def]) tm
      end

  fun conc_exec_program depth prog envfo mls =
    let 
      val holba_ss = ((std_ss++HolBACoreSimps.holBACore_ss))
      val precond = ``BExp_Const (Imm1 1w)``
      val states = symb_exec_process_to_leafs_pdecide (fn x => true) envfo depth precond prog


      (* filter for the concrete path *)
      fun eq_true t = t = ``SOME (BVal_Imm (Imm1 1w))``
      fun pathcond_val s =
	  let
	      
	      val bsst_pred_init_mem = mem_init_conc_exec ``(^s).bsst_pred`` mls
	      (* val _ = print "afetr bsst_pred_init_mem \n" *)

	      val restr_eval_tm = (rhs o concl o computeLib.RESTR_EVAL_CONV [``bir_eval_load``, ``bir_eval_store``])
					``bir_eval_exp (^bsst_pred_init_mem) (BEnv (K NONE))``;
	      (* val _ = print "afetr restr_eval_tm \n" *)
	      (* val _ = print_term (restr_eval_tm) *)
	      val bsst_simp_tm = 
                    (let 
			 val tm = ((rhs o concl) (SIMP_CONV (std_ss++HolBACoreSimps.bir_load_store_ss) [] (restr_eval_tm)))  
			     handle _ => restr_eval_tm
			 val (f,t) = Lib.first (fn (tac,t) => (Lib.can tac) t) [(load_store_simp_tac,tm), (load_store_simp_tac1,tm)]
			     handle _ => ((fn t => t), tm)
			 val res = f t
		     in
			 res
		     end)
	      (* val _ = print "afetr bsst_simp_tm \n" *)
	      (* val _ = print_term bsst_simp_tm *)
	      (* val _ = print "\n\n\n" *)

	  in
	      (snd o dest_eq o concl o EVAL) bsst_simp_tm
	  end
      (* val _ = print "before calling pathcond_val \n" *)
      val filteredStates = List.filter (eq_true o pathcond_val) states
      (* val _ = print "afetr calling pathcond_val \n" *)
      val final_state = case filteredStates of
			   [s] => s
			 | []  => raise ERR "conc_obs_compute" "no state has a true path condition?!?!?!"
                         | _   => raise ERR "conc_obs_compute" "more than one state has a true path condition?!?!?!";

    in
      final_state
    end;

  fun conc_exec_obs_extract symb_state =
    let
      fun eval_exp t = (rhs o concl o EVAL) t;
      fun eval_exp_to_val t =
        let
	    val esimp = computeLib.RESTR_EVAL_CONV [``bir_eval_load``, ``bir_eval_store``]
	    					   ``bir_eval_exp (^t) (BEnv (K NONE))``;
	    val res =
                eval_exp
	    	    (let
	    	     val tm = ((rhs o concl) (SIMP_CONV (std_ss++HolBACoreSimps.bir_load_store_ss) [] ((rhs o concl) esimp)))
	    		 handle _ => ((rhs o concl) esimp)
	    	     val res = load_store_simp_tac tm
	    		 handle _ => tm
	    	 in
	    	     res
	    	 end)

          (* val res = eval_exp ``bir_eval_exp ^t (BEnv (\x. NONE))``; *)
          val res_v = if is_some res 
		      then dest_some res 
		      else 
			  let
			      val ex = rhs res 
			  in (``(BVal_Imm (Imm64 ((n2w ^ex):word64)))``) 
			  end
                  (* raise ERR "conc_exec_obs_extract::eval_exp_to_val" "could not evaluate down to a value"; *)
        in
          res_v
        end;
      fun eval_explist_to_vallist t =
        let
          val (tl, tt) = dest_list t
                         handle _ => raise ERR "conc_exec_obs_extract::eval_explist_to_vallist" "input is not a list";
          val _ = if tt = ``:bir_exp_t`` then ()
                  else raise ERR "conc_exec_obs_extract::eval_explist_to_vallist" "wrong list type";
        in
          mk_list (map eval_exp_to_val tl, ``:bir_val_t``)
        end;
      val state_ = symb_state;
      val _ = if symb_is_BST_Halted state_ then () else
              raise ERR "conc_exec_program" "the final state is not halted, something is off";
      val (_,_,_,_,observation) = dest_bir_symb_state state_;
      val bsst_obs_init_mem = mem_init_conc_exec observation []
      val nonemp_obs = filter (fn ob => (not o List.null o snd o strip_comb) ob) [bsst_obs_init_mem];
      val obs_elem = map (fn ob => (fst o dest_list) ob)nonemp_obs;
      val obs_exp = map (fn ob => let val (c,t,f) = (dest_bir_symb_obs)  ob in (c,t,f) end) (flatten obs_elem);
      val res = List.concat
                    (map (fn (cond,ob,f) =>
                             if eval_exp_to_val cond = ``BVal_Imm (Imm1 1w)``
                             then let val t = mk_comb (f, eval_explist_to_vallist ob)
                                  in [eval_exp t] end
                             else [])
                                 obs_exp);
    in res end;

  fun conc_exec_obs_compute prog s =
    let

      fun getReg tm = case tm of regT x => x
      fun getMem tm = case tm of memT x => x 
      fun is_memT tm = can getMem tm
      val (m, rg) = List.partition (is_memT) s
      val m = if List.null m then ("MEM", []:((num * num) list)) else (getMem (hd m))
      val rg = map getReg rg
      val envfo = SOME (gen_symb_updates rg)
      (* val _ = print "before conc_exec_program \n" *)
      val state_ = conc_exec_program 200 prog envfo (#2 m)
      (* val _ = print "after conc_exec_program \n" *)
      val obs = conc_exec_obs_extract state_
      (* val _ = print "after conc_exec_obs_extract \n" *)

      val _ = map print_term obs
      val _ = print "\n";
    in
      obs
    end;

  fun conc_exec_obs_compare prog (s1, s2) =
    conc_exec_obs_compute prog s1 = conc_exec_obs_compute prog s2;


(*

open bir_cfgVizLib;
open bir_obs_modelLib;
open bir_prog_genLib;
open bir_embexp_driverLib;

open optionSyntax;
open bir_valuesSyntax;
open bir_immSyntax;
open wordsSyntax;

(*
export HOLBA_EMBEXP_LOGS="/home/xmate/Projects/HolBA/logs/EmbExp-Logs";
*)

val obs_model_id = "cache_tag_index";

(*
val exp_ids = ["arm8/exps2/exp_cache_multiw/7d4fd31c0865567aae1ab23c57256c3e6dc6215d"];
*)

val listname = "hamperiments32_eqobs";
val exp_ids = bir_embexp_load_exp_ids listname;

(*
val exp_id = hd exp_ids;
val exp_ids = tl exp_ids;
val _ = print "\n\n\n\n";
val _ = print exp_id;
val _ = print "\n=============================\n";
*)

fun compare_obss_of_exp obs_model_id exp_id =
  let
    val (asm_lines, (s1,s2)) = bir_embexp_load_exp exp_id;

    val (_, lifted_prog) = prog_gen_store_fromlines asm_lines ();

    val add_obs = #add_obs (get_obs_model obs_model_id)
    val prog = add_obs lifted_prog;
    (*
    fun convobs_fun obs = (Arbnum.toHexString o (fn x => Arbnum.* (x, Arbnum.fromInt 64)) o dest_word_literal o dest_Imm64 o dest_BVal_Imm o dest_some) obs;
    val convobsl_fun = List.map convobs_fun;

    val obsl1 = conc_exec_obs_compute prog s1;
    val obsl2 = conc_exec_obs_compute prog s2;

    val obsl1_ = convobsl_fun obsl1;
    val obsl2_ = convobsl_fun obsl2;
    *)
  in
    conc_exec_obs_compare prog (s1,s2)
  end;

val results = List.map (fn x => (compare_obss_of_exp obs_model_id x, x)) exp_ids;


val _ = List.map (fn (b, s) => if b then print (s ^ "\n") else ()) results;


val exp_id = "arm8/exps2/exp_cache_multiw/113126365c7e68aa0b83ef9f42ff6ee6407b418b";
val (asm_lines, (s1,s2)) = bir_embexp_load_exp exp_id;
val (_, lifted_prog) = prog_gen_store_fromlines asm_lines ();
val add_obs = #add_obs (get_obs_model obs_model_id)
val prog = add_obs lifted_prog;

conc_exec_obs_compute prog s1;
conc_exec_obs_compute prog s2;
conc_exec_obs_compare prog (s1,s2);


val dot_path = "/home/xmate/Projects/HolBA/HolBA/src/tools/scamv/tempdir/cfg.dot";
bir_cfgVizLib.bir_export_graph_from_prog prog dot_path;
*)
end (* struct *)
