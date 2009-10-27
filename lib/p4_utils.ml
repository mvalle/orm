(*pp camlp4orf *)

(*
 * Copyright (c) 2009 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2009 Thomas Gazagnaire <thomas@gazagnaire.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Camlp4
open PreCast
open Ast
open Syntax

module PP = Camlp4.Printers.OCaml.Make(Syntax)
let pp = new PP.printer ()
let debug_ctyp ty = Format.eprintf "DEBUG CTYP: %a@." pp#ctyp ty

(* convenience function to wrap the TyDcl constructor since I cant
   find an appropriate quotation to use for this *)
let declare_type name ty =
  let _loc = loc_of_ctyp ty in
  Ast.TyDcl (_loc, name, [], ty, [])

(* defines the Ast.binding for a function of form:
let fun_name ?(opt_arg1) ?(opt_arg2) ident1 ident2 = function_body ...
*)
let function_with_label_args ~fun_name ~idents ~function_body ~return_type opt_args =
  let _loc = loc_of_expr function_body in
  let opt_args = opt_args @ (List.map (fun x -> <:patt< $lid:x$ >>) idents) in
    <:binding< $lid:fun_name$ = 
      $List.fold_right (fun b a ->
        <:expr<fun $b$ -> $a$ >>
       ) opt_args <:expr< ( $function_body$ : $return_type$ ) >>
      $ >>

(* convert a list of bindings into an expr fragment:
   let x = 1 in y = 2 in z = 3 in ()
*)
let biList_to_expr bindings final =
  let _loc = loc_of_expr final in
  List.fold_right (fun b a -> 
    <:expr< let $b$ in $a$ >>
  ) bindings final

(* build something like 'f ?x1 ?x2 ?x3 ... xn' *)
let apply _loc f label_args =
  let make x = Ast.ExId (_loc, Ast.IdLid (_loc, x)) in
  let make_label x = Ast.ExOlb (_loc, x, Ast.ExNil _loc) in
  let rec aux = function
  | []   -> make f
  | h::t -> Ast.ExApp (_loc, aux t , make_label h) in
  aux (List.rev label_args)

let access_array _loc a i =
  let make x = Ast.ExId (_loc, Ast.IdLid (_loc, x)) in
  Ast.ExAre (_loc, make a, Ast.ExInt (_loc, string_of_int i))

(* List.map with the integer position passed to the function *)
let mapi fn =
  let pos = ref 0 in
  List.map (fun x ->
    incr pos;
    fn !pos x
  ) 
