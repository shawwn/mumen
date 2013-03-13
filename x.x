;; -*- mode: lisp -*-

;;; TODO
;; nil -> nil in Lua, nil -> undefined in JS
;; fix ARRAY-LENGTH in Lua (check for element at [0])
;; implement ERROR for Lua
;; implement [] for Lua
;; implement Array.push for Lua
;; implement argument processing for Lua
;; implement process.exit() for Lua or get rid of the call

;;; language targets

(declare current-target 'js)

(macro target (args)
  (declare i 0)
  (while (< i (array-length args))
    (if ((= (get (get args i) 0) current-target)
	 (return (get (get args i) 1))))
    (set i (+ i 1))))

(declare current-language
  (target (js 'js) (lua 'lua)))


;;; library

(function error (msg) (throw msg))

(function type (x)
  (return (target (js (typeof x)) (lua (type x)))))

;; arrays

(function array-length (arr)
  (return (target (js arr.length) (lua (+ #arr 1)))))

(function array-sub (arr start end)
  (target
    (js (return (arr.slice start end)))
    (lua
     (do (set end (or end (array-length arr)))
	 (declare i start)
	 (declare j 0)
	 (declare arr2 {})
	 (while (< i end)
	   (set (get arr2 j) (get arr i))
	   (set i (+ i 1))
	   (set j (+ j 1)))))))

;; strings

(function string-length (str)
  (return (target (js str.length) (lua (string.len str)))))

(function string-start ()
  (return (target (js 0) (lua 1))))

(function string-end (str) ; last valid position
  (return (target (js (- (string-length str) 1))
		  (lua (string-length str)))))

(function string-ref (str n)
  (return (target (js (str.charAt n)) (lua (string.sub str n n)))))

(function string-sub (str start end)
  (return (target (js (str.substring start end))
		  (lua (string.sub str start end)))))

;; io

(target (js (set fs (require "fs"))))

(function read-file (filename)
  (target
    (js (return (fs.readFileSync filename "utf8")))
    (lua (do (declare f (io.open filename))
	     (return (f:read "*a"))))))

(function write-file (filename data)
  (target
    (js (fs.writeFileSync filename data "utf8"))
    (lua (do (declare f (io.open filename "w"))
	     (f:write data)))))

(target (js (function print (x) (console.log x))))

;; numbers

(function parse-number (str)
  (target
    (js (do (declare n (parseFloat str))
	    (if ((not (isNaN n)) (return n)))))
    (lua (return (tonumber str)))))


;;; reader

(declare delimiters {})
(set (get delimiters "(") true) (set (get delimiters ")") true)
(set (get delimiters ";") true) (set (get delimiters "\n") true)

(declare whitespace {})
(set (get whitespace " ") true)
(set (get whitespace "\t") true)
(set (get whitespace "\n") true)

(function make-stream (str)
  (declare s {})
  (set s.pos (string-start))
  (set s.string str)
  (set s.end (string-end str))
  (return s))

(function peek-char (s)
  (if ((<= s.pos s.end) (return (string-ref s.string s.pos)))))

(function read-char (s)
  (declare c (peek-char s))
  (if (c (set s.pos (+ s.pos 1)) (return c))))

(function skip-non-code (s)
  (declare c)
  (while true
    (set c (peek-char s))
    (if ((not c) break)
	((get whitespace c) (read-char s))
        ((= c ";")
	 (while (and c (not (= c "\n")))
	   (set c (read-char s)))
	 (skip-non-code s))
	(true break))))

(function read-atom (s)
  (declare c)
  (declare str "")
  (while true
    (set c (peek-char s))
    (if ((and c (and (not (get whitespace c))
                     (not (get delimiters c))))
         (set str (cat str c))
         (read-char s))
        (true break)))
  (declare n (parse-number str))
  (if ((= n undefined) (return str))
      (true (return n))))

(function read-list (s)
  (read-char s) ; (
  (declare c)
  (declare l [])
  (while true
    (skip-non-code s)
    (set c (peek-char s))
    (if ((and c (not (= c ")"))) (l.push (read s)))
        (c (read-char s) break) ; )
        (true (error (cat "Expected ) at " s.pos)))))
  (return l))

(function read-string (s)
  (read-char s) ; "
  (declare c)
  (declare str "\"")
  (while true
    (set c (peek-char s))
    (if ((and c (not (= c "\"")))
         (if ((= c "\\") (set str (cat str (read-char s)))))
         (set str (cat str (read-char s))))
        (c (read-char s) break) ; "
        (true (error (cat "Expected \" at " s.pos)))))
  (return (cat str "\"")))

(function read-quote (s)
  (read-char s) ; '
  (return (list "quote" (read s))))

(function read-unquote (s)
  (read-char s) ; ,
  (return (list "unquote" (read s))))

(function read (s)
  (skip-non-code s)
  (declare c (peek-char s))
  (if ((= c "(") (return (read-list s)))
      ((= c ")") (error (cat "Unexpected ) at " s.pos)))
      ((= c "\"") (return (read-string s)))
      ((= c "'") (return (read-quote s)))
      ((= c ",") (return (read-unquote s)))
      (true (return (read-atom s)))))


;;; compiler

(declare operators {})

(function define-operators ()
  (set (get operators "+") "+") (set (get operators "-") "-")
  (set (get operators "<") "<") (set (get operators ">") ">")
  (set (get operators "<=") "<=") (set (get operators ">=") ">=")
  (set (get operators "=") "==")

  (if ((= current-target 'js)
       (set (get operators "and") "&&"))
      (true (set (get operators "and") " and ")))

  (if ((= current-target 'js)
       (set (get operators "or") "||"))
      (true (set (get operators "or") " or ")))

  (if ((= current-target 'js)
       (set (get operators "cat") "+"))
      (true (set (get operators "cat") ".."))))

(declare special {})
(set (get special "do") compile-do)
(set (get special "set") compile-set)
(set (get special "get") compile-get)
(set (get special "dot") compile-dot)
(set (get special "not") compile-not)
(set (get special "if") compile-if)
(set (get special "function") compile-function)
(set (get special "declare") compile-declare)
(set (get special "while") compile-while)
(set (get special "list") compile-list)
(set (get special "quote") compile-quote)

(declare macros {})

(function atom? (form)
  (return (or (= (type form) "string") (= (type form) "number"))))

(function call? (form)
  (return (= (type (get form 0)) "string")))

(function operator? (form)
  (return (not (= (get operators (get form 0)) null))))

(function special? (form)
  (return (not (= (get special (get form 0)) null))))

(function macro-call? (form)
  (return (not (= (get macros (get form 0)) null))))

(function macro-definition? (form)
  (return (and (call? form) (= (get form 0) "macro"))))

(function terminator (stmt?)
  (if (stmt? (return ";")) (true (return ""))))

(function compile-args (forms)
  (declare i 0)
  (declare str "(")
  (while (< i (array-length forms))
    (set str (cat str (compile (get forms i) false)))
    (if ((< i (- (array-length forms) 1)) (set str (cat str ","))))
    (set i (+ i 1)))
  (return (cat str ")")))

(function compile-body (forms)
  (declare i 0)
  (declare str "")
  (if ((= current-target 'js) (set str "{")))
  (while (< i (array-length forms))
    (set str (cat str (compile (get forms i) true)))
    (set i (+ i 1)))
  (if ((= current-target 'js)
       (return (cat str "}")))
      (true (return str))))

(function compile-atom (form stmt?)
  (declare atom form)
  (if ((and (= (type form) "string")
	    (not (= (string-ref form (string-start)) "\"")))
       (set atom (string-ref form (string-start)))
       (declare i (+ (string-start) 1)) ; skip leading -
       (while (<= i (string-end form))
	 (declare c (string-ref form i))
	 (if ((= c "-") (set c "_")))
	 (set atom (cat atom c))
	 (set i (+ i 1)))
       (declare end (string-end form))
       (if ((= (string-ref form end) "?")
	    (set atom (cat "is_" (string-sub atom 0 end)))))))
  (return (cat atom (terminator stmt?))))

(function compile-call (form stmt?)
  (declare fn (compile (get form 0) false))
  (declare args (compile-args (array-sub form 1)))
  (return (cat fn args (terminator stmt?))))

(function compile-operator (form)
  (declare i 1)
  (declare str "(")
  (declare op (get operators (get form 0)))
  (while (< i (array-length form))
    (set str (cat str (compile (get form i) false)))
    (if ((< i (- (array-length form) 1)) (set str (cat str op))))
    (set i (+ i 1)))
  (return (cat str ")")))

(function compile-do (forms stmt?)
  (if ((not stmt?)
       (error "Cannot compile DO as an expression")))
  (declare body (compile-body forms))
  (if ((= current-target 'js) (return body))
      (true (return (cat "do " body " end ")))))

(function compile-set (form stmt?)
  (if ((not stmt?)
       (error "Cannot compile assignment as an expression")))
  (if ((< (array-length form) 2)
       (error "Missing right-hand side in assignment")))
  (declare lh (compile (get form 0) false))
  (declare rh (compile (get form 1) false))
  (return (cat lh "=" rh (terminator true))))

(function compile-branch (branch first? last?)
  (declare condition (compile (get branch 0) false))
  (declare body (compile-body (array-sub branch 1)))
  (declare end "")
  (if ((and last? (= current-target 'lua)) (set end " end ")))
  (if (first?
       (if ((= current-target 'js)
	    (return (cat "if(" condition ")" body)))
	   (true (return (cat "if " condition " then " body end)))))
      ((and last? (= condition "true"))
       (if ((= current-target 'js) (return (cat "else" body)))
	   (true (return (cat " else " body " end ")))))
      (true
       (if ((= current-target 'js)
	    (return (cat "else if(" condition ")" body)))
	   (true
	    (return (cat " elseif " condition " then " body end)))))))

(function compile-if (form stmt?)
  (if ((not stmt?)
       (error "Cannot compile if as an expression")))
  (declare i 0)
  (declare str "")
  (while (< i (array-length form))
    (declare last? (= i (- (array-length form) 1)))
    (declare first? (= i 0))
    (declare branch (compile-branch (get form i) first? last?))
    (set str (cat str branch))
    (set i (+ i 1)))
  (return str))

(function compile-function (form stmt?)
  (declare name (compile (get form 0)))
  (declare args (compile-args (get form 1)))
  (declare body (compile-body (array-sub form 2)))
  (declare end "")
  (if ((= current-target 'lua) (set end " end ")))
  (return (cat "function " name args body end)))

(function compile-get (form stmt?)
  (declare object (compile (get form 0) false))
  (declare key (compile (get form 1) false))
  (return (cat object "[" key "]" (terminator stmt?))))

(function compile-dot (form stmt?)
  (declare object (compile (get form 0) false))
  (declare key (get form 1))
  (return (cat object "." key (terminator stmt?))))

(function compile-not (form stmt?)
  (declare expr (compile (get form 0) false))
  (if ((= current-target 'js)
       (return (cat "!(" expr ")" (terminator stmt?))))
      (true (return (cat "(not " expr ")" (terminator stmt?))))))

(function compile-declare (form stmt?)
  (if ((not stmt?)
       (error "Cannot compile declaration as an expression")))
  (declare lh (compile (get form 0)))
  (declare tr (terminator true))
  (declare keyword "local ")
  (if ((= current-target 'js) (set keyword "var ")))
  (if ((= (type (get form 1)) "undefined")
       (return (cat keyword lh tr)))
      (true
       (declare rh (compile (get form 1) false))
       (return (cat keyword lh "=" rh tr)))))

(function compile-while (form stmt?)
  (if ((not stmt?)
       (error "Cannot compile WHILE as an expression")))
  (declare condition (compile (get form 0) false))
  (declare body (compile-body (array-sub form 1)))
  (if ((= current-target 'js)
       (return (cat "while(" condition ")" body)))
      (true (return (cat "while " condition " do " body " end ")))))

(function compile-list (forms stmt? quoted?)
  (if (stmt?
       (error "Cannot compile LIST as a statement")))
  (declare i 0)
  (declare str "[")
  (while (< i (array-length forms))
    (declare x (get forms i))
    (declare x1)
    (if (quoted? (set x1 (quote-form x)))
	(true (set x1 (compile x false))))
    (set str (cat str x1))
    (if ((< i (- (array-length forms) 1)) (set str (cat str ","))))
    (set i (+ i 1)))
  (return (cat str "]")))

(function compile-to-string (form)
  (if ((= (type form) "string")
       (return (cat "\"" form "\"")))
      (true (return (cat form "")))))

(function quote-form (form)
  (if ((and (= (type form) "string")
	    (= (string-ref form 0) "\""))
       (return form))
      ((atom? form) (return (compile-to-string form)))
      ((= (get form 0) "unquote")
       (return (compile (get form 1) false)))
      (true (return (compile-list form false true)))))

(function compile-quote (forms stmt?)
  (if (stmt?
       (error "Cannot compile quoted form as a statement")))
  (if ((< (array-length forms) 1)
       (error "Must supply at least one argument to QUOTE")))
  (return (quote-form (get forms 0))))	; first arg only

(function compile-macro (form stmt?)
  (if ((not stmt?)
       (error "Cannot compile macro definition as an expression")))
  (declare tmp current-target)
  (set current-target current-language)
  (eval (compile-function form true))
  (declare name (get form 0))
  (declare register
    '(set (get macros ,(compile-to-string name)) ,name))
  (eval (compile register true))
  (set current-target tmp))

(function compile (form stmt?)
  (if ((= form undefined) (return ""))
      ((atom? form) (return (compile-atom form stmt?)))
      ((call? form)
       (if ((and (operator? form) stmt?)
            (error (cat "Cannot compile operator application as a statement")))
           ((operator? form)
            (return (compile-operator form)))
	   ((macro-definition? form)
	    (compile-macro (array-sub form 1) stmt?)
	    (return ""))
           ((special? form)
            (declare fn (get special (get form 0)))
            (return (fn (array-sub form 1) stmt?)))
	   ((macro-call? form)
	    (declare fn (get macros (get form 0)))
	    (declare form (fn (array-sub form 1)))
	    (return (compile form stmt?)))
           (true (return (compile-call form stmt?)))))
      (true (error (cat "Unexpected form: " form)))))

(function compile-file (filename)
  (declare form)
  (declare output "")
  (declare s (make-stream (read-file filename)))
  (while true
    (set form (read s))
    (if (form (set output (cat output (compile form true))))
        (true break)))
  (return output))

(function usage ()
  (print "usage: x input [-o output] [-t target]")
  (process.exit))

(if ((< (array-length process.argv) 3) (usage)))

(declare input (get process.argv 2))
(declare output (cat (array-sub input 0 (input.indexOf ".")) ".js"))
(declare i 3)

(while (< i (array-length process.argv))
  (declare arg (get process.argv i))
  (if ((or (= arg "-o") (= arg "-t"))
       (if ((> (array-length process.argv) (+ i 1))
	    (set i (+ i 1))
	    (declare arg2 (get process.argv i))
	    (if ((= arg "-o") (set output arg2))
		(true (set current-target arg2))))
	   (true (print "missing argument for" arg) (usage))))
      (true (print "unrecognized option:" arg) (usage)))
  (set i (+ i 1)))

(define-operators)
(write-file output (compile-file input))
