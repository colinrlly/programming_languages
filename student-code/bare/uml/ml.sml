(* ml.sml 331c *)


(*****************************************************************)
(*                                                               *)
(*   ENVIRONMENTS                                                *)
(*                                                               *)
(*****************************************************************)

(* environments 214 *)
type name = string
type 'a env = (name * 'a) list
val emptyEnv = []

(* lookup and assignment of existing bindings *)
exception NotFound of name
fun find (name, []) = raise NotFound name
  | find (name, (n, v)::tail) = if name = n then v else find (name, tail)

(* adding new bindings *)
exception BindListLength
fun bind (name, v, rho) = (name, v) :: rho
fun bindList (n::vars, v::vals, rho) = bindList (vars, vals, bind (n, v, rho))
  | bindList ([], [], rho) = rho
  | bindList _ = raise BindListLength
(* type declarations for consistency checking *)
val _ = op emptyEnv : 'a env
val _ = op find     : name * 'a env -> 'a
val _ = op bind     : name      * 'a      * 'a env -> 'a env
val _ = op bindList : name list * 'a list * 'a env -> 'a env


(*****************************************************************)
(*                                                               *)
(*   HINDLEY-MILNER TYPES                                        *)
(*                                                               *)
(*****************************************************************)

(* Hindley-Milner types ((ml/haskell)) 291 *)
datatype ty = TYVAR  of name                (* type variable alpha *)
            | TYCON  of name                (* type constructor mu *)
            | CONAPP of ty * ty list        (* type-level application *)

datatype type_scheme = FORALL of name list * ty
(* Hindley-Milner types ((ml/haskell)) 294a *)
type subst = ty env
fun varsubst theta = 
  (fn a => find (a, theta) handle NotFound _ => TYVAR a)
(* type declarations for consistency checking *)
type subst = subst
val _ = op varsubst : subst -> (name -> ty)
(* Hindley-Milner types ((ml/haskell)) 294b *)
fun tysubst theta =
  let fun subst (TYVAR a) = varsubst theta a
        | subst (TYCON c) = TYCON c
        | subst (CONAPP (tau, taus)) = CONAPP (subst tau, map subst taus)
(* type declarations for consistency checking *)
val _ = op tysubst : subst -> (ty -> ty)
val _ = op subst   :           ty -> ty
  in  subst
  end
(* Hindley-Milner types ((ml/haskell)) 294c *)
(* sets of free type variables ((ml/haskell)) 318a *)
type 'a set = 'a list
val emptyset = []
fun member x = 
  List.exists (fn y => y = x)
fun insert (x, ys) = 
  if member x ys then ys else x::ys
fun union (xs, ys) = foldl insert ys xs
fun inter (xs, ys) =
  List.filter (fn x => member x ys) xs
fun diff  (xs, ys) = 
  List.filter (fn x => not (member x ys)) xs
(* type declarations for consistency checking *)
type 'a set = 'a set
val _ = op emptyset : 'a set
val _ = op member   : ''a -> ''a set -> bool
val _ = op insert   : ''a     * ''a set  -> ''a set
val _ = op union    : ''a set * ''a set  -> ''a set
val _ = op inter    : ''a set * ''a set  -> ''a set
val _ = op diff     : ''a set * ''a set  -> ''a set
(* sets of free type variables ((ml/haskell)) 318b *)
fun freetyvars t =
  let fun f (TYVAR v,          ftvs) = insert (v, ftvs)
        | f (TYCON _,          ftvs) = ftvs
        | f (CONAPP (ty, tys), ftvs) = foldl f (f (ty, ftvs)) tys
  in  rev (f (t, emptyset))
  end  
(* type declarations for consistency checking *)
val _ = op freetyvars : ty -> name set
fun dom theta = map (fn (a, _) => a) theta
fun compose (theta2, theta1) =
  let val domain  = union (dom theta2, dom theta1)
      val replace = tysubst theta2 o varsubst theta1
  in  map (fn a => (a, replace a)) domain
  end
(* type declarations for consistency checking *)
val _ = op dom     : subst -> name set
val _ = op compose : subst * subst -> subst
(* Hindley-Milner types ((ml/haskell)) 294d *)
exception BugInTypeInference of string

fun instantiate (FORALL (formals, tau), actuals) =
  tysubst (bindList (formals, actuals, emptyEnv)) tau
  handle BindListLength => raise BugInTypeInference
                                              "number of types in instantiation"
(* type declarations for consistency checking *)
val _ = op instantiate : type_scheme * ty list -> ty
(* Hindley-Milner types ((ml/haskell)) 295a *)
val idsubst = emptyEnv
(* Hindley-Milner types ((ml/haskell)) 295b *)
infix 7 |-->
val idsubst = emptyEnv
fun a |--> (TYVAR a') = if a = a' then idsubst else bind (a, TYVAR a', emptyEnv)
  | a |--> tau        = if member a (freetyvars tau) then
                          raise BugInTypeInference "non-idempotent substitution"
                        else
                          bind (a, tau, emptyEnv)
(* type declarations for consistency checking *)
val _ = op idsubst : subst
(* type declarations for consistency checking *)
val _ = op |--> : name * ty -> subst
(* Hindley-Milner types ((ml/haskell)) 295c *)
(* printing types ((ml/haskell)) 693 *)
(* definition of [[separate]] 218d *)
fun separate (zero, sep) =  (* print list with separator *)
  let fun s []     = zero
        | s [x]    = x
        | s (h::t) = h ^ sep ^ s t
  in  s
end
val spaceSep = separate ("", " ")  (* print separated by spaces *)
local
  (* precedences *)
  val CONp   = 3
  val STARp  = 2
  val ARROWp = 1
  val NONEp  = 0
  
  fun parens s = "(" ^ s ^ ")"
  fun bracket (s, context, prec) = if prec <= context then parens s else s
  fun p (context, CONAPP (TYCON "tuple", l)) = bracket (ptuple l, context, STARp
                                                                               )
    | p (context, CONAPP (TYCON "function", [arg, ret])) = 
          bracket (p (ARROWp, arg) ^ " -> " ^ p (ARROWp, ret), context, ARROWp)
    | p (context, CONAPP (n, []))  = p (context, n)
    | p (context, CONAPP (n, [t])) = p (CONp, t) ^ " " ^ p (CONp, n)
    | p (context, CONAPP (n, l)) = 
          "(" ^ separate ("", ", ") (map typeString l) ^ ") " ^ p (CONp, n)
    | p (context, TYCON n) = n
    | p (context, TYVAR v) = "'" ^ v
  and ptuple l = separate ("unit", " * ") (map (fn t => p (STARp, t)) l)
  and typeString ty = p (NONEp, ty)
in 
  val typeString = typeString
  val ptuple = ptuple
end
fun typeSchemeString (FORALL ([], ty)) =
      typeString ty
  | typeSchemeString (FORALL (a::a's, ty)) =
      let fun combine (var, vars) = vars ^ ", '" ^ var
      in  "forall " ^ foldl combine ("'" ^ a) a's ^ " . " ^ typeString ty
      end
(* type declarations for consistency checking *)
val _ = op typeString       : ty          -> string
val _ = op typeSchemeString : type_scheme -> string
(* Hindley-Milner types ((ml/haskell)) 296a *)
fun eqType (TYCON c, TYCON c') = c = c'
  | eqType (CONAPP (tau, taus), CONAPP (tau', taus')) =
      eqType (tau, tau') andalso eqTypes (taus, taus')
  | eqType (TYVAR a, TYVAR a') = a = a'
  | eqType _ = false
and eqTypes (t::taus, t'::taus') = eqType (t, t') andalso eqTypes (taus, taus')
  | eqTypes ([], []) = true
  | eqTypes _ = false
(* Hindley-Milner types ((ml/haskell)) 296b *)
val inttype  = TYCON "int"
val booltype = TYCON "bool"
val symtype  = TYCON "sym"
val alpha    = TYVAR "a"
val beta     = TYVAR "b"
fun tupletype taus  = CONAPP (TYCON "tuple", taus)
fun pairtype (x, y) = tupletype [x, y]
val unittype        = tupletype []
fun listtype ty     = CONAPP (TYCON "list", [ty])
fun funtype (args, result) = 
  CONAPP (TYCON "function", [tupletype args, result])
(* type declarations for consistency checking *)
val _ = op eqType : ty * ty -> bool
(* type declarations for consistency checking *)
val _ = op inttype   : ty
val _ = op booltype  : ty
val _ = op symtype   : ty
val _ = op unittype  : ty
val _ = op listtype  : ty -> ty
val _ = op tupletype : ty list -> ty
val _ = op pairtype  : ty * ty -> ty
val _ = op funtype   : ty list * ty -> ty
val _ = op alpha     : ty
val _ = op beta      : ty
(* Hindley-Milner types ((ml/haskell)) 319a *)
local
  val n = ref 1
in
  fun freshtyvar _ = TYVAR ("t" ^ Int.toString (!n) before n := !n + 1)
(* type declarations for consistency checking *)
val _ = op freshtyvar : 'a -> ty
end
(* Hindley-Milner types ((ml/haskell)) 319b *)
fun canonicalize (FORALL (bound, ty)) =
  let fun canonicalTyvarName n =
        if n < 26 then str (chr (ord #"a" + n))
        else "v" ^ Int.toString (n - 25)
      val free = diff (freetyvars ty, bound)
      fun unusedIndex n =
        if member (canonicalTyvarName n) free then unusedIndex (n+1) else n
      fun newBoundVars (index, [])                = []
        | newBoundVars (index, oldvar :: oldvars) =
            let val n = unusedIndex index
            in  canonicalTyvarName n :: newBoundVars (n+1, oldvars)
            end
      val newBound = newBoundVars (0, bound)
(* type declarations for consistency checking *)
val _ = op canonicalize : type_scheme -> type_scheme
val _ = op newBoundVars : int * name list -> name list
  in  FORALL (newBound, tysubst (bindList (bound, map TYVAR newBound, emptyEnv))
                                                                             ty)
  end
(* Hindley-Milner types ((ml/haskell)) 319c *)
fun generalize (tau, tyvars) =
  canonicalize (FORALL (diff (freetyvars tau, tyvars), tau))
(* type declarations for consistency checking *)
val _ = op generalize : ty * name set -> type_scheme
(* Hindley-Milner types ((ml/haskell)) 320a *)
fun freshInstance (FORALL (bound, tau)) =
  instantiate (FORALL (bound, tau), map freshtyvar bound)
(* type declarations for consistency checking *)
val _ = op freshInstance : type_scheme -> ty
(* Hindley-Milner types ((ml/haskell)) 320b *)
datatype con = =*= of ty  * ty
             | /\  of con * con
             | TRIVIAL
infix 4 =*=
infix 3 /\
(* Hindley-Milner types ((ml/haskell)) 320c *)
(* printing constraints ((ml/haskell)) 694a *)
fun untriviate (c /\ c') = (case (untriviate c, untriviate c')
                              of (TRIVIAL, c) => c
                               | (c, TRIVIAL) => c
                               | (c, c') => c /\ c')
  | untriviate atomic = atomic

fun constraintString (c /\ c')  = constraintString c ^ " /\\ " ^
                                                             constraintString c'
  | constraintString (t =*= t') = typeString t ^ " =*= " ^ typeString t'
  | constraintString TRIVIAL = "TRIVIAL"
(* type declarations for consistency checking *)
val _ = op constraintString : con -> string
(* Hindley-Milner types ((ml/haskell)) 320d *)
fun freetyvarsConstraint (t =*= t') = union (freetyvars t, freetyvars t')
  | freetyvarsConstraint (c /\  c') = union (freetyvarsConstraint c,
                                             freetyvarsConstraint c')
  | freetyvarsConstraint TRIVIAL    = emptyset
(* Hindley-Milner types ((ml/haskell)) 320e *)
fun consubst theta =
  let fun subst (tau1 =*= tau2) = tysubst theta tau1 =*= tysubst theta tau2
        | subst (c1 /\ c2)      = subst c1 /\ subst c2
        | subst TRIVIAL         = TRIVIAL
  in  subst
  end
(* type declarations for consistency checking *)
val _ = op consubst : subst -> con -> con
(* Hindley-Milner types ((ml/haskell)) 320f *)
fun conjoinConstraints []      = TRIVIAL
  | conjoinConstraints [c]     = c
  | conjoinConstraints (c::cs) = c /\ conjoinConstraints cs
(* type declarations for consistency checking *)
val _ = op conjoinConstraints : con list -> con
(* Hindley-Milner types ((ml/haskell)) 321a *)
exception TypeError of string

fun unsatisfiableEquality (t1, t2) =
  case canonicalize (FORALL (union (freetyvars t1, freetyvars t2), tupletype [t1
                                                                         , t2]))
    of FORALL (_, CONAPP (TYCON "tuple", [t1, t2])) => 
         raise TypeError ("cannot make " ^ typeString t1 ^ " equal to " ^
                                                                  typeString t2)
     | _ => let exception ThisCan'tHappen in raise ThisCan'tHappen end
(* Hindley-Milner types ((ml/haskell)) 321c *)
(* constraint solving ((prototype)) 321b *)
exception LeftAsExercise of string
fun solve c = raise LeftAsExercise "solve"
(* type declarations for consistency checking *)
val _ = op solve : con -> subst
(* constraint solving 809 *)
fun solve (TRIVIAL)  = idsubst
  | solve (c1 /\ c2) =
      let val theta1 = solve c1
          val theta2 = solve (consubst theta1 c2)
      in  compose (theta2, theta1)
      end
  | solve (tau =*= tau') =
      case (tau, tau')
        of (TYVAR a, tau) => solveTyvarEq (a, tau)
         | (tau, TYVAR a) => solveTyvarEq (a, tau)
         | (TYCON mu, TYCON mu') => if mu = mu' then idsubst
                                    else unsatisfiableEquality (tau, tau')
         | (CONAPP (t, ts), CONAPP (t', ts')) =>
             let fun eqAnd (t, t', c) = t =*= t' /\ c
             in  solve (ListPair.foldlEq eqAnd TRIVIAL (t::ts, t'::ts'))
                 handle ListPair.UnequalLengths => unsatisfiableEquality (tau,
                                                                           tau')
             end
         | _ => unsatisfiableEquality (tau, tau')

and solveTyvarEq (a, tau) = 
      if eqType (TYVAR a, tau) then
        idsubst
      else if member a (freetyvars tau) then
        unsatisfiableEquality (TYVAR a, tau)
      else
        a |--> tau
(* constraint solving 810a *)
fun isStandard pairs =
  let fun distinct a' (a, tau) = a <> a' andalso not (member a' (freetyvars tau)
                                                                               )
      fun good (prev', (a, tau)::next) =
            List.all (distinct a) prev' andalso List.all (distinct a) next
            andalso good ((a, tau)::prev', next)
        | good (_, []) = true
  in  good ([], pairs)
  end

val solve =
  fn c => let val theta = solve c
          in  if isStandard theta then theta
              else raise BugInTypeInference "non-standard substitution"
          end
(* Hindley-Milner types ((ml/haskell)) 322a *)
type type_env = type_scheme env * name set
(* Hindley-Milner types ((ml/haskell)) 322b *)
val emptyTypeEnv = 
      (emptyEnv, emptyset)
fun findtyscheme (v, (Gamma, free)) = find (v, Gamma)
(* type declarations for consistency checking *)
val _ = op emptyTypeEnv : type_env
val _ = op findtyscheme : name * type_env -> type_scheme
(* Hindley-Milner types ((ml/haskell)) 322c *)
fun bindtyscheme (v, sigma as FORALL (bound, tau), (Gamma, free)) = 
  (bind (v, sigma, Gamma), union (diff (freetyvars tau, bound), free))
(* Hindley-Milner types ((ml/haskell)) 322d *)
fun freetyvarsGamma (_, free) = free


(*****************************************************************)
(*                                                               *)
(*   LEXICAL ANALYSIS                                            *)
(*                                                               *)
(*****************************************************************)

(* lexical analysis ((mlscheme)) 671a *)
datatype token = NAME    of string
               | INT     of int
               | SHARP   of bool
               | BRACKET of char (* ( or ) *)
               | QUOTE
(* lexical analysis ((mlscheme)) 671b *)
fun tokenString (NAME x)    = x
  | tokenString (INT  n)    = Int.toString n
  | tokenString (SHARP b)   = if b then "#t" else "#f"
  | tokenString (BRACKET c) = str c
  | tokenString (QUOTE)     = "'"

fun isLiteral s t = tokenString t = s
(* support for streams, lexical analysis, and parsing 644 *)
(* suspensions 646 *)
datatype 'a action
  = PENDING  of unit -> 'a
  | PRODUCED of 'a

type 'a susp = 'a action ref

fun delay f = ref (PENDING f)
fun force cell =
  case !cell
    of PENDING f =>  let val result = f ()
                     in  (cell := PRODUCED result; result)
                     end
     | PRODUCED v => v
(* type declarations for consistency checking *)
val _ = op delay : (unit -> 'a) -> 'a susp
val _ = op force : 'a susp -> 'a
(* streams 647a *)
datatype 'a stream 
  = EOS
  | :::       of 'a * 'a stream
  | SUSPENDED of 'a stream susp
infixr 3 :::
(* streams 647b *)
fun streamGet EOS = NONE
  | streamGet (x ::: xs)    = SOME (x, xs)
  | streamGet (SUSPENDED s) = streamGet (force s)
(* streams 647c *)
fun streamOfList xs = 
  foldr (op :::) EOS xs
(* type declarations for consistency checking *)
val _ = op streamGet : 'a stream -> ('a * 'a stream) option
(* type declarations for consistency checking *)
val _ = op streamOfList : 'a list -> 'a stream
(* streams 647d *)
fun listOfStream xs =
  case streamGet xs
    of NONE => []
     | SOME (x, xs) => x :: listOfStream xs
(* streams 647e *)
fun delayedStream action = 
  SUSPENDED (delay action)
(* type declarations for consistency checking *)
val _ = op listOfStream : 'a stream -> 'a list
(* type declarations for consistency checking *)
val _ = op delayedStream : (unit -> 'a stream) -> 'a stream
(* streams 648a *)
fun streamOfEffects next =
  delayedStream (fn () => case next () of NONE => EOS
                                        | SOME a => a ::: streamOfEffects next)
(* type declarations for consistency checking *)
val _ = op streamOfEffects : (unit -> 'a option) -> 'a stream
(* streams 648b *)
type line = string
fun streamOfLines infile = 
  streamOfEffects (fn () => TextIO.inputLine infile)
(* type declarations for consistency checking *)
type line = line
val _ = op streamOfLines : TextIO.instream -> line stream
(* streams 648c *)
fun streamRepeat x =
  delayedStream (fn () => x ::: streamRepeat x)
(* type declarations for consistency checking *)
val _ = op streamRepeat : 'a -> 'a stream
(* streams 648d *)
fun streamOfUnfold next state =
  delayedStream (fn () => case next state
                            of NONE => EOS
                             | SOME (a, state) => a ::: streamOfUnfold next
                                                                          state)
(* type declarations for consistency checking *)
val _ = op streamOfUnfold : ('b -> ('a * 'b) option) -> 'b -> 'a stream
(* streams 649a *)
fun preStream (pre, xs) = 
  streamOfUnfold (fn xs => (pre (); streamGet xs)) xs
(* streams 649b *)
fun postStream (xs, post) =
  streamOfUnfold (fn xs => case streamGet xs
                             of NONE => NONE
                              | head as SOME (x, _) => (post x; head)) xs
(* type declarations for consistency checking *)
val _ = op preStream : (unit -> unit) * 'a stream -> 'a stream
(* type declarations for consistency checking *)
val _ = op postStream : 'a stream * ('a -> unit) -> 'a stream
(* streams 649c *)
fun streamMap f xs =
  delayedStream (fn () => case streamGet xs
                            of NONE => EOS
                             | SOME (x, xs) => f x ::: streamMap f xs)
(* type declarations for consistency checking *)
val _ = op streamMap : ('a -> 'b) -> 'a stream -> 'b stream
(* streams 649d *)
fun streamFilter p xs =
  delayedStream (fn () => case streamGet xs
                            of NONE => EOS
                             | SOME (x, xs) => if p x then x ::: streamFilter p
                                                                              xs
                                               else streamFilter p xs)
(* type declarations for consistency checking *)
val _ = op streamFilter : ('a -> bool) -> 'a stream -> 'a stream
(* streams 650a *)
fun streamFold f z xs =
  case streamGet xs of NONE => z
                     | SOME (x, xs) => streamFold f (f (x, z)) xs
(* type declarations for consistency checking *)
val _ = op streamFold : ('a * 'b -> 'b) -> 'b -> 'a stream -> 'b

(* streams 650b *)
fun streamZip (xs, ys) =
  delayedStream
  (fn () => case (streamGet xs, streamGet ys)
              of (SOME (x, xs), SOME (y, ys)) => (x, y) ::: streamZip (xs, ys)
               | _ => EOS)
(* streams 650c *)
fun streamConcat xss =
  let fun get (xs, xss) =
        case streamGet xs
          of SOME (x, xs) => SOME (x, (xs, xss))
           | NONE => case streamGet xss
                       of SOME (xs, xss) => get (xs, xss)
                        | NONE => NONE
  in  streamOfUnfold get (EOS, xss)
  end
(* type declarations for consistency checking *)
val _ = op streamZip : 'a stream * 'b stream -> ('a * 'b) stream
(* type declarations for consistency checking *)
val _ = op streamConcat : 'a stream stream -> 'a stream
(* streams 650d *)
fun streamConcatMap f xs = streamConcat (streamMap f xs)
(* type declarations for consistency checking *)
val _ = op streamConcatMap : ('a -> 'b stream) -> 'a stream -> 'b stream
(* streams 650e *)
infix 5 @@@
fun xs @@@ xs' = streamConcat (streamOfList [xs, xs'])
(* type declarations for consistency checking *)
val _ = op @@@ : 'a stream * 'a stream -> 'a stream
(* error handling 651a *)
datatype 'a error = OK of 'a | ERROR of string
(* error handling 651b *)
infix 1 >>=
fun (OK x)      >>= k  =  k x
  | (ERROR msg) >>= k  =  ERROR msg
(* type declarations for consistency checking *)
val _ = op >>= : 'a error * ('a -> 'b error) -> 'b error
(* error handling 652a *)
infix 1 >>=+
fun e >>=+ k'  =  e >>= OK o k'
(* type declarations for consistency checking *)
val _ = op >>=+ : 'a error * ('a -> 'b) -> 'b error
(* error handling 652b *)
fun errorList es =
  let fun cons (OK x, OK xs) = OK (x :: xs)
        | cons (ERROR m1, ERROR m2) = ERROR (m1 ^ "; " ^ m2)
        | cons (ERROR m, OK _) = ERROR m
        | cons (OK _, ERROR m) = ERROR m
  in  foldr cons (OK []) es
  end
(* parsing combinators 652c *)
type ('a, 'b) xformer = 
  'a stream -> ('b error * 'a stream) option
(* type declarations for consistency checking *)
val _ = op errorList : 'a error list -> 'a list error
(* type declarations for consistency checking *)
type ('a, 'b) xformer = ('a, 'b) xformer
(* parsing combinators 653a *)
fun pure y = fn xs => SOME (OK y, xs)
(* type declarations for consistency checking *)
val _ = op pure : 'b -> ('a, 'b) xformer
(* parsing combinators 653b *)
infix 3 <*>
fun tx_f <*> tx_b =
  fn xs => case tx_f xs
             of NONE => NONE
              | SOME (ERROR msg, xs) => SOME (ERROR msg, xs)
              | SOME (OK f, xs) =>
                  case tx_b xs
                    of NONE => NONE
                     | SOME (ERROR msg, xs) => SOME (ERROR msg, xs)
                     | SOME (OK y, xs) => SOME (OK (f y), xs)
(* type declarations for consistency checking *)
val _ = op <*> : ('a, 'b -> 'c) xformer * ('a, 'b) xformer -> ('a, 'c) xformer
(* parsing combinators 653c *)
infixr 4 <$>
fun f <$> p = pure f <*> p
(* type declarations for consistency checking *)
val _ = op <$> : ('b -> 'c) * ('a, 'b) xformer -> ('a, 'c) xformer
(* parsing combinators 654a *)
fun id x = x
fun fst (x, y) = x
fun snd (x, y) = y
fun pair x y = (x, y)
fun curry  f x y   = f (x, y)
fun curry3 f x y z = f (x, y, z)
(* type declarations for consistency checking *)
val _ = op fst    : ('a * 'b) -> 'a
val _ = op snd    : ('a * 'b) -> 'b
val _ = op pair   : 'a -> 'b -> 'a * 'b
val _ = op curry  : ('a * 'b -> 'c) -> ('a -> 'b -> 'c)
val _ = op curry3 : ('a * 'b * 'c -> 'd) -> ('a -> 'b -> 'c -> 'd)
(* parsing combinators 654b *)
infix 1 <|>
fun t1 <|> t2 = (fn xs => case t1 xs of SOME y => SOME y | NONE => t2 xs) 
(* type declarations for consistency checking *)
val _ = op <|> : ('a, 'b) xformer * ('a, 'b) xformer -> ('a, 'b) xformer
(* parsing combinators 655a *)
infix 3 <* *>
fun p1 <*  p2 = curry fst <$> p1 <*> p2
fun p1  *> p2 = curry snd <$> p1 <*> p2

infixr 4 <$
fun v <$ p = (fn _ => v) <$> p
(* type declarations for consistency checking *)
val _ = op <*  : ('a, 'b) xformer * ('a, 'c) xformer -> ('a, 'b) xformer
val _ = op  *> : ('a, 'b) xformer * ('a, 'c) xformer -> ('a, 'c) xformer
val _ = op <$  : 'b               * ('a, 'c) xformer -> ('a, 'b) xformer
(* parsing combinators 655b *)
fun one xs = case streamGet xs
               of NONE => NONE
                | SOME (x, xs) => SOME (OK x, xs)
(* type declarations for consistency checking *)
val _ = op one : ('a, 'a) xformer
(* parsing combinators 655c *)
fun eos xs = case streamGet xs
               of NONE => SOME (OK (), EOS)
                | SOME _ => NONE
(* type declarations for consistency checking *)
val _ = op eos : ('a, unit) xformer
(* parsing combinators 655d *)
fun peek tx xs = case tx xs of SOME (OK y, _) => SOME y
                             | _ => NONE
(* type declarations for consistency checking *)
val _ = op peek : ('a, 'b) xformer -> 'a stream -> 'b option
(* parsing combinators 656a *)
fun rewind tx xs = case tx xs of SOME (ey, _) => SOME (ey, xs)
                               | NONE => NONE
(* type declarations for consistency checking *)
val _ = op rewind : ('a, 'b) xformer -> ('a, 'b) xformer
(* parsing combinators 656b *)
fun sat p tx xs =
  case tx xs
    of answer as SOME (OK y, xs) => if p y then answer else NONE
     | answer => answer
(* type declarations for consistency checking *)
val _ = op sat : ('b -> bool) -> ('a, 'b) xformer -> ('a, 'b) xformer
(* parsing combinators 656c *)
fun oneEq x = sat (fn x' => x = x') one
(* type declarations for consistency checking *)
val _ = op oneEq : ''a -> (''a, ''a) xformer
(* parsing combinators 657a *)
infixr 4 <$>?
fun f <$>? tx =
  fn xs => case tx xs
             of NONE => NONE
              | SOME (ERROR msg, xs) => SOME (ERROR msg, xs)
              | SOME (OK y, xs) =>
                  case f y
                    of NONE => NONE
                     | SOME z => SOME (OK z, xs)
(* type declarations for consistency checking *)
val _ = op <$>? : ('b -> 'c option) * ('a, 'b) xformer -> ('a, 'c) xformer
(* parsing combinators 657b *)
infix 3 <&>
fun t1 <&> t2 = fn xs =>
  case t1 xs
    of SOME (OK _, _) => t2 xs
     | SOME (ERROR _, _) => NONE    
     | NONE => NONE
(* type declarations for consistency checking *)
val _ = op <&> : ('a, 'b) xformer * ('a, 'c) xformer -> ('a, 'c) xformer
(* parsing combinators 657c *)
fun notFollowedBy t xs =
  case t xs
    of NONE => SOME (OK (), xs)
     | SOME _ => NONE
(* type declarations for consistency checking *)
val _ = op notFollowedBy : ('a, 'b) xformer -> ('a, unit) xformer
(* parsing combinators 657d *)
fun many t = 
  curry (op ::) <$> t <*> (fn xs => many t xs) <|> pure []
(* type declarations for consistency checking *)
val _ = op many  : ('a, 'b) xformer -> ('a, 'b list) xformer
(* parsing combinators 658a *)
fun many1 t = 
  curry (op ::) <$> t <*> many t
(* type declarations for consistency checking *)
val _ = op many1 : ('a, 'b) xformer -> ('a, 'b list) xformer
(* parsing combinators 658b *)
fun optional t = 
  SOME <$> t <|> pure NONE
(* type declarations for consistency checking *)
val _ = op optional : ('a, 'b) xformer -> ('a, 'b option) xformer
(* parsing combinators 658c *)
infix 2 <*>!
fun tx_ef <*>! tx_x =
  fn xs => case (tx_ef <*> tx_x) xs
             of NONE => NONE
              | SOME (OK (OK y),      xs) => SOME (OK y,      xs)
              | SOME (OK (ERROR msg), xs) => SOME (ERROR msg, xs)
              | SOME (ERROR msg,      xs) => SOME (ERROR msg, xs)
infixr 4 <$>!
fun ef <$>! tx_x = pure ef <*>! tx_x
(* type declarations for consistency checking *)
val _ = op <*>! : ('a, 'b -> 'c error) xformer * ('a, 'b) xformer -> ('a, 'c)
                                                                         xformer
val _ = op <$>! : ('b -> 'c error)             * ('a, 'b) xformer -> ('a, 'c)
                                                                         xformer
(* support for lexical analysis 659a *)
type 'a lexer = (char, 'a) xformer
(* type declarations for consistency checking *)
type 'a lexer = 'a lexer
(* support for lexical analysis 659b *)
fun isDelim c = Char.isSpace c orelse Char.contains "();" c
(* type declarations for consistency checking *)
val _ = op isDelim : char -> bool
(* support for lexical analysis 659c *)
val whitespace = many (sat Char.isSpace one)
(* type declarations for consistency checking *)
val _ = op whitespace : char list lexer
(* support for lexical analysis 660a *)
fun intChars isDelim = 
  (curry (op ::) <$> oneEq #"-" <|> pure id) <*> many1 (sat Char.isDigit one) <*
                                                                                
  notFollowedBy (sat (not o isDelim) one)
(* type declarations for consistency checking *)
val _ = op intChars     : (char -> bool) -> char list lexer
(* support for lexical analysis 660b *)
fun intFromChars (#"-" :: cs) = 
      intFromChars cs >>=+ ~
  | intFromChars cs =
      (OK o valOf o Int.fromString o implode) cs
      handle Overflow => ERROR
                        "this interpreter can't read arbitrarily large integers"
(* type declarations for consistency checking *)
val _ = op intFromChars : char list -> int error
(* support for lexical analysis 660c *)
fun intToken isDelim =
  intFromChars <$>! intChars isDelim
(* type declarations for consistency checking *)
val _ = op intToken : (char -> bool) -> int lexer
(* support for parsing 660d *)
(* token, isLiteral, and
   tokenString can be defined
   differently in each language *)
(* support for parsing 661a *)
type srcloc = string * int
fun srclocString (source, line) =
  source ^ ", line " ^ Int.toString line
(* support for parsing 661b *)
fun errorAt msg loc =
  ERROR (msg ^ " in " ^ srclocString loc)
(* support for parsing 661c *)
type 'a located = srcloc * 'a
(* type declarations for consistency checking *)
type token = token
val _ = op isLiteral : string -> token -> bool
val _ = op tokenString : token -> string
(* type declarations for consistency checking *)
type srcloc = srcloc
val _ = op srclocString : srcloc -> string
(* type declarations for consistency checking *)
val _ = op errorAt : string -> srcloc -> 'a error
(* type declarations for consistency checking *)
type 'a located = 'a located
(* support for parsing 661d *)
fun locatedStream (streamname, inputs) =
  let val locations = streamZip (streamRepeat streamname,
                                 streamOfUnfold (fn n => SOME (n, n+1)) 1)
  in  streamZip (locations, inputs)
  end
(* type declarations for consistency checking *)
val _ = op locatedStream : string * line stream -> line located stream
(* support for parsing 662a *)
datatype 'a inline
  = EOL of int (* number of the line that ends here *)
  | INLINE of 'a

fun drainLine EOS = EOS
  | drainLine (SUSPENDED s)     = drainLine (force s)
  | drainLine (EOL _    ::: xs) = xs
  | drainLine (INLINE _ ::: xs) = drainLine xs
(* parsing utilities 662b *)
type 'a parser = (token located inline, 'a) xformer
(* parsing utilities 663a *)
local 
  fun asEol (EOL n) = SOME n
    | asEol (INLINE _) = NONE
  fun asInline (INLINE x) = SOME x
    | asInline (EOL _)    = NONE
in
  fun eol    xs = (asEol <$>? one) xs
  fun inline xs = (many eol *> asInline <$>? one) xs
end

val token    =         snd <$> inline  : token parser
val srcloc   = rewind (fst <$> inline) : srcloc parser
val noTokens = notFollowedBy token : unit parser
(* type declarations for consistency checking *)
type 'a inline = 'a inline
val _ = op drainLine : 'a inline stream -> 'a inline stream
(* type declarations for consistency checking *)
type 'a parser = 'a parser
(* type declarations for consistency checking *)
val _ = op eol      : ('a inline, int) xformer
val _ = op inline   : ('a inline, 'a)  xformer
val _ = op token    : token parser
val _ = op srcloc   : srcloc parser
val _ = op noTokens : unit parser
(* parsing utilities 663b *)
fun @@ p = pair <$> srcloc <*> p
(* type declarations for consistency checking *)
val _ = op @@ : 'a parser -> 'a located parser
(* parsing utilities 663c *)

infix 0 <?>
fun p <?> expected = p <|> errorAt ("expected " ^ expected) <$>! srcloc
(* type declarations for consistency checking *)
val _ = op <?> : 'a parser * string -> 'a parser
(* parsing utilities 664a *)
infix 4 <!>
fun p <!> msg =
  fn tokens => (case p tokens
                  of SOME (OK _, unused) =>
                       (case peek srcloc tokens
                          of SOME loc => SOME (errorAt msg loc, unused)
                           | NONE => NONE)
                   | _ => NONE)
(* parsing utilities 664b *)
fun literal s =
  ignore <$> sat (isLiteral s) token
(* type declarations for consistency checking *)
val _ = op <!> : 'a parser * string -> 'b parser
(* type declarations for consistency checking *)
val _ = op literal : string -> unit parser
(* parsing utilities 664c *)
infix  6 --<
infixr 7 >-- 
    (* if we want to mix these operators, they can't have equal precedence *)
fun (a >-- p) = literal a *> p
fun (p --< a) = p <* literal a
(* type declarations for consistency checking *)
val _ = op >-- : string    * 'a parser -> 'a parser
val _ = op --< : 'a parser * string    -> 'a parser
(* parsing utilities 665 *)

fun bracket keyword expected p = 
  "(" >-- literal keyword *> (p --< ")" <|>
                              errorAt ("expected " ^ expected) <$>!
                                                               scanToCloseParen)
and scanToCloseParen tokens = 
  let val loc = getOpt (peek srcloc tokens, ("end of stream", 9999))
      fun scan lpcount tokens =
        (* lpcount is the number of unmatched left parentheses *)
        case tokens
          of EOL _         ::: tokens => scan lpcount tokens
           | INLINE (_, t) ::: tokens =>
                                  if isLiteral "(" t then scan (lpcount+1)
                                                                          tokens
                                  else if isLiteral ")" t then
                                      if lpcount = 0 then SOME (OK loc, tokens)
                                      else scan (lpcount-1) tokens
                                  else scan lpcount tokens
           | EOS         => SOME (errorAt "unmatched (" loc, EOS)
           | SUSPENDED s => scan lpcount (force s)
  in  scan 0 tokens
  end
(* type declarations for consistency checking *)
val _ = op bracket          : string -> string -> 'a parser -> 'a parser
val _ = op scanToCloseParen : srcloc parser
(* parsing utilities 666a *)
fun nodups (what, where') (loc, names) =
  let fun dup [] = OK names
        | dup (x::xs) = if List.exists (fn y : string => y = x) xs then
                          errorAt (what ^ " " ^ x ^ " appears twice in " ^
                                                                     where') loc
                        else
                          dup xs
  in  dup names
  end
(* type declarations for consistency checking *)
val _ = op nodups : string * string -> srcloc * name list -> name list error
(* code used to debug parsers 666b *)
val safeTokens : token located inline stream -> token list =
  let fun tokens (seenEol, seenUnforced) =
            let fun get (EOL _         ::: ts) = if seenUnforced then []
                                                 else tokens (true, false) ts
                  | get (INLINE (_, t) ::: ts) = t :: get ts
                  | get  EOS                   = []
                  | get (SUSPENDED (ref (PRODUCED ts))) = get ts
                  | get (SUSPENDED s) = if seenEol then []
                                        else tokens (false, true) (force s)
            in   get
            end
  in  tokens (false, false)
  end
(* type declarations for consistency checking *)
val _ = op safeTokens : token located inline stream -> token list
(* code used to debug parsers 667a *)
fun wrap what p tokens =
  let fun t tok = " " ^ tokenString tok
      val _ = app print ["Looking for ", what, " at"]
      val _ = app (print o t) (safeTokens tokens)
      val _ = print "\n"
      val answer = p tokens
      val _ = app print [case answer of NONE => "Didn't find " | SOME _ =>
                                                                       "Found ",
                         what, "\n"]
  in  answer
  end handle e => ( app print ["Search for ", what, " raised ", exnName e, "\n"]
                  ; raise e)

fun wrap what p = p 
(* type declarations for consistency checking *)
val _ = op wrap : string -> 'a parser -> 'a parser
(* an interactive reader 667b *)
fun echoTagStream lines = 
  let fun echoIfTagged line =
        if (String.substring (line, 0, 2) = ";#" handle _ => false) then
          print line
        else
          ()
  in  postStream (lines, echoIfTagged)
  end
(* type declarations for consistency checking *)
val _ = op echoTagStream : line stream -> line stream 
(* an interactive reader 667c *)
fun errorln s = TextIO.output (TextIO.stdErr, s ^ "\n")
(* type declarations for consistency checking *)
val _ = op errorln : string -> unit
(* an interactive reader 668a *)
fun stripErrors xs =
  let fun next xs =
        case streamGet xs
          of SOME (ERROR msg, xs) => (errorln ("error: " ^ msg); next xs)
           | SOME (OK x, xs) => SOME (x, xs)
           | NONE => NONE
  in  streamOfUnfold next xs
  end
(* type declarations for consistency checking *)
val _ = op stripErrors : 'a error stream -> 'a stream
(* an interactive reader 668b *)
fun lexLineWith lexer =
  stripErrors o streamOfUnfold lexer o streamOfList o explode
(* type declarations for consistency checking *)
val _ = op lexLineWith : token lexer -> line -> token stream
(* an interactive reader 668c *)
fun parseWithErrors parser =
  let fun adjust (SOME (ERROR msg, tokens)) = SOME (ERROR msg, drainLine tokens)
        | adjust other = other
  in  streamOfUnfold (adjust o parser)
  end
(* type declarations for consistency checking *)
val _ = op parseWithErrors : 'a parser -> token located inline stream -> 'a
                                                                    error stream
(* an interactive reader 668d *)
type prompts   = { ps1 : string, ps2 : string }
val stdPrompts = { ps1 = "-> ", ps2 = "   " }
val noPrompts  = { ps1 = "", ps2 = "" }
(* type declarations for consistency checking *)
type prompts = prompts
val _ = op stdPrompts : prompts
val _ = op noPrompts  : prompts
(* an interactive reader 669 *)
fun 'a reader (lexer, parser) prompts (name, lines) =
  let val { ps1, ps2 } = prompts
      val thePrompt = ref ps1
      fun setPrompt ps = fn _ => thePrompt := ps

      val lines = preStream (fn () => print (!thePrompt), echoTagStream lines)

      fun lexAndDecorate (loc, line) =
        let val tokens = postStream (lexLineWith lexer line, setPrompt ps2)
        in  streamMap INLINE (streamZip (streamRepeat loc, tokens)) @@@
            streamOfList [EOL (snd loc)]
        end

      val edefs : 'a error stream = 
        (parseWithErrors parser o streamConcatMap lexAndDecorate o locatedStream
                                                                               )
        (name, lines)
(* type declarations for consistency checking *)
val _ = op reader : token lexer * 'a parser -> prompts -> string * line stream
                                                                    -> 'a stream
val _ = op lexAndDecorate : srcloc * line -> token located inline stream
  in  
      stripErrors (preStream (setPrompt ps1, edefs))
  end 
(* lexical analysis ((mlscheme)) 672a *)
local
  (* functions used in the lexer for \uscheme 672b *)
  fun atom "#t" = SHARP true
    | atom "#f" = SHARP false
    | atom x    = NAME x
  (* functions used in the lexer for \uscheme 672c *)
  fun noneIfLineEnds chars =
    case streamGet chars
      of NONE => NONE (* end of line *)
       | SOME (#";", cs) => NONE (* comment *)
       | SOME (c, cs) => 
           let val msg = "invalid initial character in `" ^
                         implode (c::listOfStream cs) ^ "'"
           in  SOME (ERROR msg, EOS)
           end
  (* type declarations for consistency checking *)
  val _ = op noneIfLineEnds : 'a lexer
in
  val schemeToken =
    whitespace *> (   BRACKET <$> oneEq #"("
                  <|> BRACKET <$> oneEq #")"
                  <|> QUOTE   <$  oneEq #"'"
                  <|> INT     <$> intToken isDelim
                  <|> (atom o implode) <$> many1 (sat (not o isDelim) one)
                  <|> noneIfLineEnds
                  )
(* type declarations for consistency checking *)
val _ = op schemeToken : token lexer
val _ = op atom : string -> token
end


(*****************************************************************)
(*                                                               *)
(*   ABSTRACT SYNTAX AND VALUES                                  *)
(*                                                               *)
(*****************************************************************)

(* abstract syntax and values ((ml)) 287a *)
datatype exp = LITERAL of value
             | VAR     of name
             | IFX     of exp * exp * exp
             | BEGIN   of exp list
             | APPLY   of exp * exp list
             | LETX    of let_kind * (name * exp) list * exp
             | LAMBDA  of name list * exp
and let_kind = LET | LETREC | LETSTAR
and (* definition of [[value]] 287c *)
    value = NIL
          | BOOL      of bool
          | NUM       of int
          | SYM       of name
          | PAIR      of value * value
          | CLOSURE   of lambda * (unit -> value env)
          | PRIMITIVE of primop
    withtype primop = value list -> value (* raises RuntimeError *)
         and lambda = name list * exp
    exception RuntimeError of string (* error message *)
(* abstract syntax and values ((ml)) 287b *)
datatype def = VAL    of name * exp
             | VALREC of name * exp
             | EXP    of exp
             | DEFINE of name * (name list * exp)
             | USE    of name


(*****************************************************************)
(*                                                               *)
(*   VALUES                                                      *)
(*                                                               *)
(*****************************************************************)

(* values ((mlscheme)) 216b *)



fun embedList []     = NIL
  | embedList (h::t) = PAIR (h, embedList t)
fun embedPredicate f = fn x => BOOL (f x)
fun bool (BOOL b) = b
  | bool _        = true
(* type declarations for consistency checking *)
val _ = op embedList      : value list -> value
val _ = op embedPredicate : ('a -> bool) -> ('a -> value)
val _ = op bool           : value -> bool
(* values ((mlscheme)) 217a *)
fun valueString (NIL)    = "()"
  | valueString (BOOL b) = if b then "#t" else "#f"
  | valueString (NUM n)  = String.map (fn #"~" => #"-" | c => c) (Int.toString n
                                                                               )
  | valueString (SYM v)  = v
  | valueString (PAIR (car, cdr))  = 
      let fun tail (PAIR (car, cdr)) = " " ^ valueString car ^ tail cdr
            | tail NIL = ")"
            | tail v = " . " ^ valueString v ^ ")"
      in  "(" ^ valueString car ^ tail cdr
      end
  | valueString (CLOSURE   _) = "<procedure>"
  | valueString (PRIMITIVE _) = "<procedure>"
(* type declarations for consistency checking *)
val _ = op valueString : value -> string


(*****************************************************************)
(*                                                               *)
(*   PARSING                                                     *)
(*                                                               *)
(*****************************************************************)

(* parsing ((ml)) 694b *)
fun letDups LETSTAR (loc, bindings) = OK bindings
  | letDups kind    (loc, bindings) =
      let val names    = map (fn (n, _) => n) bindings
          val kindName = case kind of LET => "let" | LETREC => "letrec" | _ =>
                                                                            "??"
      in  nodups ("bound name", kindName) (loc, names) >>=+ (fn _ => bindings)
      end
fun noExp kind _ _ =
  ERROR ("uML does not include '" ^ kind ^ "' expressions")
(* parsing ((ml)) 695a *)

val name    = (fn (NAME  n) => SOME n  | _ => NONE) <$>? token
val booltok = (fn (SHARP b) => SOME b  | _ => NONE) <$>? token
val int     = (fn (INT   n) => SOME n  | _ => NONE) <$>? token
val quote   = (fn (QUOTE)   => SOME () | _ => NONE) <$>? token

fun exp tokens = (
     VAR              <$> name
 <|> (LITERAL o NUM)  <$> int
 <|> (LITERAL o BOOL) <$> booltok
 <|> LITERAL          <$> (quote *> sexp)
 <|> bracket "if"     "(if e1 e2 e3)"            (curry3 IFX <$> exp <*> exp <*>
                                                                            exp)
 <|> bracket "while"  "(while e1 e2)"            (noExp "while" <$> exp <*>! exp
                                                                               )
 <|> bracket "set"    "(set x e)"                (noExp "set"   <$> name <*>!
                                                                            exp)
 <|> bracket "begin"  ""                         (       BEGIN <$> many exp)
 <|> bracket "lambda" "(lambda (names) body)"    (     lambda  <$> @@ formals
                                                                       <*>! exp)
 <|> bracket "let"    "(let (bindings) body)"    (letx LET     <$> @@ bindings
                                                                       <*>! exp)
 <|> bracket "letrec" "(letrec (bindings) body)" (letx LETREC  <$> @@ bindings
                                                                       <*>! exp)
 <|> bracket "let*"   "(let* (bindings) body)"   (letx LETSTAR <$> @@ bindings
                                                                       <*>! exp)
 <|> "(" >-- literal ")" <!> "empty application"
 <|> curry APPLY <$> "(" >-- exp <*> many exp --< ")"
) tokens
and lambda xs exp =
  nodups ("formal parameter", "lambda") xs >>=+ (fn xs => LAMBDA (xs, exp))
and letx kind bs exp = letDups kind bs >>=+ (fn bs => LETX (kind, bs, exp))
and formals  ts = ("(" >-- many name --< ")") ts
and bindings ts = ("(" >-- (many binding --< ")" <?> "(x e)...")) ts
and binding  ts = ("(" >-- (pair <$> name <*> exp --< ")" <?>
                                                        "(x e) in bindings")) ts

and sexp tokens = (
     SYM <$> (notDot <$>! name)
 <|> NUM          <$> int
 <|> BOOL         <$> booltok
 <|> (fn v => embedList [SYM "quote", v]) <$> (quote *> sexp)
 <|> embedList    <$> "(" >-- many sexp --< ")"
) tokens
and notDot "." = ERROR
                      "this interpreter cannot handle . in quoted S-expressions"
  | notDot s   = OK s
(* parsing ((ml)) 695b *)
fun define f formals body =
  nodups ("formal parameter", "definition of function " ^ f) formals >>=+
  (fn xs => DEFINE (f, (xs, body)))

val def = 
     bracket "define"  "(define f (args) body)" (define <$> name <*> @@ formals
                                                                        <*>!exp)
 <|> bracket "val"     "(val x e)"              (curry VAL    <$> name <*> exp)
 <|> bracket "val-rec" "(val-rec x e)"          (curry VALREC <$> name <*> exp)
 <|> bracket "use"     "(use filename)"         (USE          <$> name)
 <|> literal ")" <!> "unexpected right parenthesis"
 <|> EXP <$> exp
 <?> "definition"
(* parsing ((ml)) 696a *)
val mlSyntax = (schemeToken, def)


(*****************************************************************)
(*                                                               *)
(*   IMPLEMENTATION OF [[USE]]                                   *)
(*                                                               *)
(*****************************************************************)

(* implementation of [[use]] 222a *)
fun use readEvalPrint syntax filename rho =
      let val fd = TextIO.openIn filename
          val defs = reader syntax noPrompts (filename, streamOfLines fd)
          fun writeln s = app print [s, "\n"]
          fun errorln s = TextIO.output (TextIO.stdErr, s ^ "\n")
      in  readEvalPrint (defs, writeln, errorln) rho
          before TextIO.closeIn fd
      end 


(*****************************************************************)
(*                                                               *)
(*   TYPE INFERENCE                                              *)
(*                                                               *)
(*****************************************************************)

(* type inference ((ml)) 322e *)
fun typeof (e, Gamma) =
  let (* function [[typesof]], to infer the types of a list of expressions ((ml/
                                                               haskell)) 323a *)
      fun typesof ([],    Gamma) = ([], TRIVIAL)
        | typesof (e::es, Gamma) =
            let val (tau,  c)  = typeof  (e,  Gamma)
                val (taus, c') = typesof (es, Gamma)
            in  (tau :: taus, c /\ c')
            end
      (* function [[literal]], to infer the type of a literal constant ((
                                                             prototype)) 323c *)
      fun literal _ = raise LeftAsExercise "literal"
      (* function [[ty]], to infer the type of an expression, given [[Gamma]] ((
                                                                    ml)) 323b *)
      fun ty (LITERAL n) = literal n
        | ty (VAR x) = (freshInstance (findtyscheme (x, Gamma)), TRIVIAL)
        (* more alternatives for [[ty]] 324a *)
        | ty (APPLY (f, actuals)) = 
             (case typesof (f :: actuals, Gamma)
                of ([], _) => let exception ThisCan'tHappen in raise
                                                             ThisCan'tHappen end
                 | (funty :: actualtypes, c) =>
                      let val rettype = freshtyvar ()
                      in  (rettype, c /\ (funty =*= funtype (actualtypes,
                                                                      rettype)))
                      end)
        (* more alternatives for [[ty]] 324b *)
        | ty (LETX (LETSTAR, [], body)) = ty body
        | ty (LETX (LETSTAR, (b :: bs), body)) = 
            ty (LETX (LET, [b], LETX (LETSTAR, bs, body)))
        (* more alternatives for [[ty]] ((prototype)) 324c *)
        | ty (IFX (e1, e2, e3))        = raise LeftAsExercise "type for IFX"
        | ty (BEGIN es)                = raise LeftAsExercise "type for BEGIN"
        | ty (LAMBDA (formals, body))  = raise LeftAsExercise "type for LAMBDA"
        | ty (LETX (LET, bs, body))    = raise LeftAsExercise "type for LET"
        | ty (LETX (LETREC, bs, body)) = raise LeftAsExercise "type for LETREC"
(* type declarations for consistency checking *)
val _ = op bindtyscheme : name * type_scheme * type_env -> type_env
(* type declarations for consistency checking *)
val _ = op freetyvarsGamma : type_env -> name set
(* type declarations for consistency checking *)
val _ = op typeof  : exp      * type_env -> ty      * con
val _ = op typesof : exp list * type_env -> ty list * con
val _ = op literal : value -> ty * con
val _ = op ty      : exp   -> ty * con
  in  ty e
  end
(* type inference ((ml)) 324d *)
fun elabdef (d, Gamma) =
  case d
    of VAL    (x, e)      => (* infer and bind type for [[VAL    (x, e)]] 325a
                                                                              *)
                             let val (tau, c) = typeof (e, Gamma)
                                 val theta    = solve c
                                 val sigma    = generalize (tysubst theta tau,
                                                          freetyvarsGamma Gamma)
                             in  (bindtyscheme (x, sigma, Gamma),
                                                         typeSchemeString sigma)
                             end
     | VALREC (x, e)      => (* infer and bind type for [[VALREC (x, e)]] 325b
                                                                              *)
                             let val alpha    = freshtyvar ()
                                 val Gamma'   = bindtyscheme (x, FORALL ([],
                                                                  alpha), Gamma)
                                 val (tau, c) = typeof (e, Gamma')
                                 val theta    = solve (c /\ alpha =*= tau)
                                 val sigma    = generalize (tysubst theta alpha,
                                                          freetyvarsGamma Gamma)
                             in  (bindtyscheme (x, sigma, Gamma),
                                                         typeSchemeString sigma)
                             end
     | EXP e              => elabdef (VAL ("it", e), Gamma)
     | DEFINE (x, lambda) => elabdef (VALREC (x, LAMBDA lambda), Gamma)
     | USE filename       => raise RuntimeError 
                                     "internal error -- `use' reached elabdef"
(* type declarations for consistency checking *)
val _ = op elabdef : def * type_env -> type_env * string


(*****************************************************************)
(*                                                               *)
(*   CHECKING AND EVALUATION                                     *)
(*                                                               *)
(*****************************************************************)

(* checking and evaluation ((ml)) 330a *)
(* evaluation ((ml)) 326a *)
(* definition of [[separate]] 218d *)
fun separate (zero, sep) =  (* print list with separator *)
  let fun s []     = zero
        | s [x]    = x
        | s (h::t) = h ^ sep ^ s t
  in  s
end
val spaceSep = separate ("", " ")  (* print separated by spaces *)
fun eval (e, rho) =
  let fun ev (LITERAL n)        = n
        | ev (VAR x)            = find (x, rho)
        | ev (IFX (e1, e2, e3)) = ev (if bool (ev e1) then e2 else e3)
        | ev (LAMBDA l)         = CLOSURE (l, fn _ => rho)
        | ev (BEGIN es) =
            let fun b (e::es, lastval) = b (es, ev e)
                  | b (   [], lastval) = lastval
            in  b (es, BOOL false)
            end
        | ev (APPLY (f, args)) = 
           (case ev f
              of PRIMITIVE prim => prim (map ev args)
               | CLOSURE clo => (* apply closure [[clo]] to [[args]] ((ml)) 326b
                                                                              *)
                                let val ((formals, body), mkRho) = clo
                                    val actuals = map ev args
                                in  eval (body, bindList (formals, actuals,
                                                                      mkRho ()))
                                    handle BindListLength => 
                                        raise BugInTypeInference
                                          "Wrong number of arguments to closure"
                                end
               | _ => raise BugInTypeInference "Applied non-function"
               )
        (* more alternatives for [[ev]] ((ml)) 326c *)
        | ev (LETX (LET, bs, body)) =
            let val (names, values) = ListPair.unzip bs
            in  eval (body, bindList (names, map ev values, rho))
            end
        (* more alternatives for [[ev]] ((ml)) 326d *)
        | ev (LETX (LETSTAR, bs, body)) =
            let fun step ((n, e), rho) = bind (n, eval (e, rho), rho)
            in  eval (body, foldl step rho bs)
            end
        (* more alternatives for [[ev]] ((ml)) 327a *)
        | ev (LETX (LETREC, bs, body)) =
            let fun makeRho' () =
                  let fun step ((n, e), rho) =
                            (case e
                               of LAMBDA l => bind (n, CLOSURE (l, makeRho'),
                                                                            rho)
                                | _ => raise RuntimeError "non-lambda in letrec"
                                                                               )
                  in  foldl step rho bs
                  end
            in  eval (body, makeRho'())
            end
  in  ev e
  end
(* type declarations for consistency checking *)
val _ = op eval : exp * value env -> value
(* evaluation ((ml)) 327b *)
fun evaldef (d, rho) =
  case d
    of VAL    (name, e)      =>
          let val v   = eval (e, rho)
              val rho = bind (name, v, rho)
          in  (rho, showVal name v)
          end
     | VALREC (name, LAMBDA lambda) => 
          let fun makeRho' () = bind (name, CLOSURE (lambda, makeRho'), rho)
              val v           = CLOSURE (lambda, makeRho')
          in  (makeRho'(), showVal name v)
          end
     | VALREC _ => raise RuntimeError "expression in val-rec must be lambda"
     | EXP e    => 
          let val v   = eval (e, rho)
              val rho = bind ("it", v, rho)
          in  (rho, valueString v)
          end
     | DEFINE (name, lambda) => evaldef (VALREC (name, LAMBDA lambda), rho)
     | USE filename => raise RuntimeError
                                       "internal error -- `use' reached evaldef"
and showVal name v =
      case v
        of CLOSURE   _ => name
         | PRIMITIVE _ => name
         | _ => valueString v
(* type declarations for consistency checking *)
val _ = op evaldef : def * value env -> value env * string
(* evaluation ((ml)) 328a *)
fun binaryOp f = (fn [a, b] => f (a, b) | _ => raise BugInTypeInference
                                                                      "arity 2")
fun unaryOp  f = (fn [a]    => f  a     | _ => raise BugInTypeInference
                                                                      "arity 1")
(* type declarations for consistency checking *)
val _ = op unaryOp  : (value         -> value) -> (value list -> value)
val _ = op binaryOp : (value * value -> value) -> (value list -> value)
(* evaluation ((ml)) 328b *)
fun arithOp f =
      binaryOp (fn (NUM n1, NUM n2) => NUM (f (n1, n2)) 
                 | _ => raise BugInTypeInference "arithmetic on non-numbers")
val arithtype = funtype ([inttype, inttype], inttype)
(* type declarations for consistency checking *)
val _ = op arithOp   : (int * int -> int) -> (value list -> value)
val _ = op arithtype : ty
(* evaluation ((ml)) 328d *)
fun predOp f     = unaryOp  (embedPredicate f)
fun comparison f = binaryOp (embedPredicate f)
fun intcompare f = 
      comparison (fn (NUM n1, NUM n2) => f (n1, n2)
                   | _ => raise BugInTypeInference "comparing non-numbers")
fun predtype x = funtype ([x],    booltype)
fun comptype x = funtype ([x, x], booltype)
(* type declarations for consistency checking *)
val _ = op predOp     : (value         -> bool) -> (value list -> value)
val _ = op comparison : (value * value -> bool) -> (value list -> value)
val _ = op intcompare : (int   * int   -> bool) -> (value list -> value)
val _ = op predtype   : ty -> ty
val _ = op comptype   : ty -> ty
type env_bundle = type_env * value env
fun elabEvalDef (d, envs as (Gamma, rho), echo) =
  case d
    of USE filename => use readCheckEvalPrint mlSyntax filename envs
     | _ =>
        let val (Gamma, tystring)  = elabdef (d, Gamma)
            val (rho,   valstring) = evaldef (d, rho)
            val _ = if size valstring > 0 then echo (valstring ^ " : " ^
                                                                       tystring)
                    else ()
(* type declarations for consistency checking *)
val _ = op elabEvalDef : def * env_bundle * (string->unit) -> env_bundle
        in  (Gamma, rho)
        end
(* checking and evaluation ((ml)) 330b *)
and readCheckEvalPrint (defs, echo, errmsg) envs =
  let fun processDef (def, envs) =
            let fun continue msg = (errmsg msg; envs)
            in  elabEvalDef (def, envs, echo)
                handle IO.Io {name, ...} => continue ("I/O error: " ^ name)
                (* more read-eval-print handlers 330c *)
                | TypeError          msg => continue ("type error: " ^ msg)
                | BugInTypeInference msg => continue ("bug in type inference: "
                                                                          ^ msg)
                (* more read-eval-print handlers 222c *)
                (* more read-eval-print handlers 223a *)
                | Div               => continue "Division by zero"
                | Overflow          => continue "Arithmetic overflow"
                | RuntimeError msg  => continue ("run-time error: " ^ msg)
                | NotFound n        => continue ("variable " ^ n ^ " not found")
            end
  in  streamFold processDef envs defs
  end
(* type declarations for consistency checking *)
val _ = op readCheckEvalPrint : def stream * (string->unit) * (string->unit) ->
                                                        env_bundle -> env_bundle


(*****************************************************************)
(*                                                               *)
(*   INITIALIZATION                                              *)
(*                                                               *)
(*****************************************************************)

(* initialization ((ml)) 331a *)
val initialEnvs =
  let fun addPrim ((name, prim, tau), (Gamma, rho)) = 
        ( bindtyscheme (name, generalize (tau, freetyvarsGamma Gamma), Gamma)
        , bind (name, PRIMITIVE prim, rho)
        )
      val envs  = foldl addPrim (emptyTypeEnv, emptyEnv) ((* primops [[::]] ((ml
                                                                      )) 328c *)
                                                          ("+", arithOp op +,
                                                                   arithtype) ::
                                                          ("-", arithOp op -,
                                                                   arithtype) ::
                                                          ("*", arithOp op *,
                                                                   arithtype) ::
                                                          ("/", arithOp op div,
                                                                   arithtype) ::
                                                          (* primops [[::]] ((ml
                                                                      )) 329a *)
                                                          ("<", intcompare op <,
                                                            comptype inttype) ::
                                                          (">", intcompare op >,
                                                            comptype inttype) ::
                                                          ("=", comparison (fn (
                                                       NIL,     NIL)     => true
                                                                             | (
                                                    NUM n1,  NUM n2)  => n1 = n2
                                                                             | (
                                                    SYM v1,  SYM v2)  => v1 = v2
                                                                             | (
                                                    BOOL b1, BOOL b2) => b1 = b2
                                                                             |
                                                     _                 => false)
                                                               , comptype alpha)
                                                                              ::
                                                          ("null?", predOp (fn
                        NIL => true | _ => false), predtype (listtype alpha)) ::
                                                          (* primops [[::]] ((ml
                                                                      )) 329b *)
                                                          ("cons", binaryOp (fn
                                                         (a, b) => PAIR (a, b)),

                           funtype ([alpha, listtype alpha], listtype alpha)) ::
                                                          ("car",  unaryOp  (fn
                                                          (PAIR (car, _)) => car
                                                                              |
                           NIL => raise RuntimeError "car applied to empty list"
                                                                              |
                     _   => raise BugInTypeInference "car applied to non-list"),

                                           funtype ([listtype alpha], alpha)) ::
                                                          ("cdr",  unaryOp  (fn
                                                          (PAIR (_, cdr)) => cdr
                                                                              |
                           NIL => raise RuntimeError "cdr applied to empty list"
                                                                              |
                     _   => raise BugInTypeInference "cdr applied to non-list"),

                                  funtype ([listtype alpha], listtype alpha)) ::
                                                          (* primops [[::]] ((ml
                                                                      )) 329c *)
                                                          ("print", unaryOp (fn
                                        x => (print (valueString x ^ "\n"); x)),
                                                                       funtype (
                                                          [alpha], unittype)) ::
                                                          ("error", unaryOp (fn
                                       x => raise RuntimeError (valueString x)),
                                                                       funtype (
                                                         [alpha], beta)) :: nil)
      val basis = (* ML representation of initial basis (generated by a script)
                                                                              *)

                   [ "(define list1 (x) (cons x '()))"
                   , "(define bind (x y alist)"
                   , "  (if (null? alist)"
                   , "    (list1 (pair x y))"
                   , "    (if (= x (fst (car alist)))"
                   , "      (cons (pair x y) (cdr alist))"
                   , "      (cons (car alist) (bind x y (cdr alist))))))"
                   , "(define isbound? (x alist)"
                   , "  (if (null? alist) "
                   , "    #f"
                   , "    (if (= x (fst (car alist)))"
                   , "      #t"
                   , "      (isbound? x (cdr alist)))))"
                   , "(define find (x alist)"
                   , "  (if (null? alist) "
                   , "    (error 'not-found)"
                   , "    (if (= x (fst (car alist)))"
                   , "      (snd (car alist))"
                   , "      (find x (cdr alist)))))"
                   , "(define caar (l) (car (car l)))"
                   , "(define cadr (l) (car (cdr l)))"
                   , "(define cdar (l) (cdr (car l)))"
                   , "(define length (l)"
                   , "  (if (null? l) 0"
                   , "    (+ 1 (length (cdr l)))))"
                   , "(define and (b c) (if b  c  b))"
                   , "(define or  (b c) (if b  b  c))"
                   , "(define not (b)   (if b #f #t))"
                   , "(define append (xs ys)"
                   , "  (if (null? xs)"
                   , "     ys"
                   , "     (cons (car xs) (append (cdr xs) ys))))"
                   , "(define revapp (xs ys)"
                   , "  (if (null? xs)"
                   , "     ys"
                   , "     (revapp (cdr xs) (cons (car xs) ys))))"
                   , "(define o (f g) (lambda (x) (f (g x))))"
                   , "(define curry   (f) (lambda (x) (lambda (y) (f x y))))"
                   , "(define uncurry (f) (lambda (x y) ((f x) y)))"
                   , "(define filter (p? l)"
                   , "  (if (null? l)"
                   , "    '()"
                   , "    (if (p? (car l))"
                   , "      (cons (car l) (filter p? (cdr l)))"
                   , "      (filter p? (cdr l)))))"
                   , "(define map (f l)"
                   , "  (if (null? l)"
                   , "    '()"
                   , "    (cons (f (car l)) (map f (cdr l)))))"
                   , "(define exists? (p? l)"
                   , "  (if (null? l)"
                   , "    #f"
                   , "    (if (p? (car l)) "
                   , "      #t"
                   , "      (exists? p? (cdr l)))))"
                   , "(define all? (p? l)"
                   , "  (if (null? l)"
                   , "    #t"
                   , "    (if (p? (car l))"
                   , "      (all? p? (cdr l))"
                   , "      #f)))"
                   , "(define foldr (op zero l)"
                   , "  (if (null? l)"
                   , "    zero"
                   , "    (op (car l) (foldr op zero (cdr l)))))"
                   , "(define foldl (op zero l)"
                   , "  (if (null? l)"
                   , "    zero"
                   , "    (foldl op (op (car l) zero) (cdr l))))"
                   , "(define <= (x y) (not (> x y)))"
                   , "(define >= (x y) (not (< x y)))"
                   , "(define != (x y) (not (= x y)))"
                   , "(define max (x y) (if (> x y) x y))"
                   , "(define min (x y) (if (< x y) x y))"
                   , "(define mod (m n) (- m (* n (/ m n))))"
                   , "(define gcd (m n) (if (= n 0) m (gcd n (mod m n))))"
                   , "(define lcm (m n) (* m (/ n (gcd m n))))"
                   , "(define min* (l) (foldr min (car l) (cdr l)))"
                   , "(define max* (l) (foldr max (car l) (cdr l)))"
                   , "(define gcd* (l) (foldr gcd (car l) (cdr l)))"
                   , "(define lcm* (l) (foldr lcm (car l) (cdr l)))"
                   , "(define list1 (x)               (cons x '()))"
                   , "(define list2 (x y)             (cons x (list1 y)))"
                   , "(define list3 (x y z)           (cons x (list2 y z)))"
                   , "(define list4 (x y z a)         (cons x (list3 y z a)))"
                   , "(define list5 (x y z a b)       (cons x (list4 y z a b)))"
                   ,
                   "(define list6 (x y z a b c)     (cons x (list5 y z a b c)))"
                   ,
                 "(define list7 (x y z a b c d)   (cons x (list6 y z a b c d)))"
                   ,
               "(define list8 (x y z a b c d e) (cons x (list7 y z a b c d e)))"
                   , "(define takewhile (p? l)"
                   , "  (if (null? l)"
                   , "     '()"
                   , "     (if (p? (car l))"
                   , "         (cons (car l) (takewhile p? (cdr l)))"
                   , "         '())))"
                   , "(define dropwhile (p? l)"
                   , "  (if (null? l)"
                   , "     '()"
                   , "     (if (p? (car l))"
                   , "         (dropwhile p? (cdr l))"
                   , "         l)))"
                    ]
      val defs  = reader mlSyntax noPrompts ("initial basis", streamOfList basis
                                                                               )
      fun errout s = TextIO.output(TextIO.stdErr, s ^ "\n")
  in  readCheckEvalPrint (defs, fn _ => (), errout) envs
  end
(* initialization ((ml)) 331b *)
fun runInterpreter noisy = 
  let fun writeln s = app print [s, "\n"]
      fun errout s = TextIO.output(TextIO.stdErr, s ^ "\n")
      val prompts = if noisy then stdPrompts else noPrompts
      val defs = reader mlSyntax prompts ("standard input", streamOfLines
                                                                   TextIO.stdIn)
  in  ignore (readCheckEvalPrint (defs, writeln, errout) initialEnvs)
  end 


(*****************************************************************)
(*                                                               *)
(*   COMMAND LINE                                                *)
(*                                                               *)
(*****************************************************************)

(* command line 223d *)
fun main ["-q"] = runInterpreter false
  | main []     = runInterpreter true
  | main _      =
      TextIO.output (TextIO.stdErr, "Usage: " ^ CommandLine.name () ^ " [-q]\n")
val _ = main (CommandLine.arguments ())
