;;; SRFI-28: Basic format strings.

(define (format format-string . objects)
  (let ((buffer (open-output-string)))
    (let loop ((format-list (string->list format-string))
               (objects objects))
      (cond ((null? format-list) (get-output-string buffer))
            ((char=? (car format-list) #\~)
             (if (null? (cdr format-list))
                 (error 'format "Incomplete escape sequence")
                 (case (cadr format-list)
                   ((or #\a #\A)
                    (if (null? objects)
                        (error 'format "No value for escape sequence")
                        (begin
                          (display (car objects) buffer)
                          (loop (cddr format-list) (cdr objects)))))
                   ((or #\s #\S)
                    (if (null? objects)
                        (error 'format "No value for escape sequence")
                        (begin
                          (write (car objects) buffer)
                          (loop (cddr format-list) (cdr objects)))))
                   ((#\%)
                    (newline buffer)
                    (loop (cddr format-list) objects))
                   ((#\~)
                    (write-char #\~ buffer)
                    (loop (cddr format-list) objects))
                   (else
                    (error 'format "Unrecognized escape sequence")))))
            (else (write-char (car format-list) buffer)
                  (loop (cdr format-list) objects))))))

;; eof
