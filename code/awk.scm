;;; -*- Mode: Scheme; -*-

;; awkward.scm -- Do AWK-like things from Scheme (awkwardly)

;; AWK built-in variables:

;; - FS: Field separator, defaults to " "

;; - OFS: Output field separator, defaults to " "

;; - RS: Record separator, defaults to "\n"

;; - ORS: Output record separator, defaults to "\n"

;; - NF: Number of fields in the current input record.  Set for each
;;   record (usually a line).

;; - NR: Number of input records that have been processed during
;;   program execution.  Set each time a new record is read.

(define $FS "[ \t]+")                        ; regexp used by pregexp-split
(define $OFS " ")
(define $RS "\n")
(define $ORS "\n")
(define $NF 0)
(define $NR 0)

(define BEGIN #t)
(define END #t)

(define (print s)
  (display s)
  (newline))

(define (process-file file)
  (awk* file
        ;; Run a BEGIN block
        '((BEGIN print "Hello World!")
         ;; Print lines matching a regex
         ("/Dan/" print $1)             ; works
         ;; Print names of people who didn't work last week
         ((== $3 0) print (string-append $1 " made 0 dollars")))))

;; Output of PROCESS-FILE is still very strange:
;; Hello World!
;; Beth made 0 dollars

;; Dan

;; Dan made 0 dollars
;; $75 = #f

;; Validate pattern-action pairs

(define (get-pattern pair)
  (car pair))

(define (get-action pair)
  (cdr pair))



(define (awk* file pattern-actions)
  (set! BEGIN #t)
  (for-each-line
   (lambda (line)
     (let* ((field-vars (build-field-vars line))
            (expanded-patterns (rewrite-vars pattern-actions field-vars)))
       (begin
         (for-each (lambda (pa)
                     (apply-pattern pa line)) expanded-patterns))))
   file))

;; ++ This is using some scsh APIs in the prototype, which will need to be fixed.
;; ++ This needs to be expanded to handle expressions, e.g. `($3 == 19)`.

(define (apply-pattern pattern-action line)
  ;; if the pattern is a string, it's a regex
  ;; if it's a sexp, it's something using a var from the line's environment
  ;; pull the pattern off the list, then the CDR is the action
  (let ((pattern (car pattern-action))
        (action (cdr pattern-action)))
    (cond ((string? pattern)
           ;; Regex case
           (let* ((stripped (strip-slashes pattern))
                  (re (pregexp stripped)))
             (if (pregexp-match re line)
                 (eval action (interaction-environment)))))
          ((equal? pattern 'BEGIN)
           (if BEGIN                    ; Set by caller
               (begin
                 (eval action (interaction-environment))
                 (set! BEGIN #f))))
          ((list? pattern)
           ;; Sexp case
           (let* ((pat (car pattern-action))
                  (act (cdr pattern-action)))
             (if (eval pat (interaction-environment))
                 (eval act (interaction-environment)))))
          (else #f))))

(define (== x y)
  (cond ((and (number? x) (number? y))
         (= x y))
        ((and (string? x) (number? y))
         (let ((n (string->number x)))
           (if n
               (= n y))))
        ((and (number? x) (string? y))
         (let ((n (string->number y)))
           (if n
               (= n x))))
        ((and (string? x) (string? y))
         (string=? x y))
        (else #f)))

(define (strip-slashes string)
  (let* ((xs (string->list string))
         (*xs (cdr xs))
         (xs* (cdr (reverse *xs)))
         (ys (reverse xs*))
         (ss (list->string ys)))
    ss))

(define (rewrite-vars exp env)
  (define (rewrite-vars-helper exp env)
    (map (lambda (x)
           (if (atom? x)
               (let ((val (? x env)))
                 (if (not (string=? val ""))
                     val
                     x))
               (rewrite-vars-helper x env)))
         exp))
  (map (lambda (exp*) (rewrite-vars-helper exp* env)) exp))

;; get and set vars in the per-line environment

(define (get-var var env)
  ;; Symbol Alist -> Object
  (let ((val (assoc var env)))
    (if val (cdr val) "")))

(define (set-var var val env)
  ;; Symbol Object -> Alist
  (let ((pair (cons var val)))
    (cons pair env)))

(define ? get-var)
(define ! set-var)

;; build the per-line environment

(define (build-field-vars line)
  ;; String Regexp -> Alist
  ;; (build-field-vars "Hello it's me")
  ;; => '(($0 . "Hello it's me") ($1 . "Hello") ($2 . "It's") ($3 . "Me"))
  (let* ((pieces (string-split $FS line))
         ($NF (length pieces))
         (results (list (cons '$NF $NF))))
    (let loop ((pieces pieces)
               (results results)
               (count 0))
      (if (null? pieces)
          (reverse results)
          (cond ((= count 0)
                 (let ((var (make-field-var count)))
                   (loop pieces
                         (cons (cons var line) results)
                         (+ count 1))))
                (else
                 (let ((var (make-field-var count))
                       (this (car pieces))
                       (rest (cdr pieces)))
                   (loop rest
                         (cons (cons var this) results)
                         (+ count 1)))))))))

;; build the field variable name

(define (make-field-var n)
  ;; Integer -> Symbol
  (let* ((s (number->string n))
         (var-string (string-append "$" s)))
    (string->symbol var-string)))



;; testing intermediate states

(apply-pattern
 (let ((expanded (rewrite-vars '(("/Dan/" display $1) ((== $3 0) display $1)) (build-field-vars "Daniel in the lion's den"))))
   (first expanded))
 "Daniel in the lion's den")
;; ==> Daniel

(let ((expanded (rewrite-vars '(("/Dan/" display $1) ((== $3 0) display $1)) (build-field-vars "Daniel in the lion's den"))))
    (first expanded))
;; ==> '("/Dan/" display "Daniel")

(rewrite-vars '(("/Dan/" display $1) ((== $3 0) display $1)) (build-field-vars "Daniel in the lion's den"))
;; ==> '(("/Dan/" display "Daniel") ((== "the" 0) display "Daniel"))



;;; Hypothetical usage/API

;; ++ Clearly this macro definition is wrong.

'(define-syntax awk
   (syntax-rules ()
     ((awk ?file
           ?pat ?body ...
           ?pat2 ?body2 ...)
      (awk* ?file
            '((?pat ?body)
              (?pat2 ?body2)
              (...))))))

'(awk file
      "^#" (display $0)
      "/Status/" (format "~A, Date, ~A, ~A, Notes~%" $1 $2 $3))
