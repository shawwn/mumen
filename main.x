;; -*- mode: lisp -*-

(define rep (str)
  (pr (eval (compile-toplevel (read-from-string str)))))

(define repl ()
  (let (execute (fn (str) (rep str) (write "> ")))
    (write "> ")
    (target
     (js (do (process.stdin.resume)
	     (process.stdin.setEncoding 'utf8)
	     (process.stdin.on 'data execute)))
     (lua (while true
	    (let (str (io.stdin:read))
	      (if str (execute str) break)))))))

(define usage ()
  (pr "usage: x [options] [inputs]")
  (pr "options:")
  (pr "  -o <output>\tOutput file")
  (pr "  -t <target>\tTarget language (default: lua)")
  (pr "  -e <expr>\tExpression to evaluate")
  (pr "  -m \t\tEmbed macro definitions in output")
  (exit))

(define main ()
  (set! args (target (js (sub process.argv 2)) (lua arg)))
  (if (or (= (at args 0) "-h")
	  (= (at args 0) "--help"))
      (usage))
  (let (inputs ()
        output nil
        target1 nil
	expr nil)
    (across (args arg i)
      (if (or (= arg "-o") (= arg "-t") (= arg "-e"))
	  (if (= i (- (length args) 1))
	      (pr "missing argument for" arg)
	    (do (set! i (+ i 1))
		(let (arg2 (at args i))
		  (if (= arg "-o") (set! output arg2)
		      (= arg "-t") (set! target1 arg2)
		      (= arg "-e") (set! expr arg2)))))
	  (= arg "-m") (set! embed-macros? true)
	  (= "-" (sub arg 0 1))
	  (do (pr "unrecognized option:" arg) (usage))
	(push! inputs arg)))
    (if output
	(do (if target1 (set! target target1))
	    (let (compiled (compile-files inputs)
		  main (compile '(main) true))
	      (write-file output (cat compiled macros main))))
      ;; TODO: rethink evaluation strategy
      (do (across (inputs file)
	    (eval (compile-file file)))
	  (if expr (rep expr) (repl))))))
