(in-package :aws-lambda-runtime)

(defun find-handler-from-aws-standard-format (handler-string)
  "Tries to find a handler by AWS Lambda's standard format.
 See `find-handler''s docstring"
  (let* ((dot-pos (position #\. handler-string))
	 (file-name (subseq handler-string 0 dot-pos))
	 (symbol-name (subseq handler-string (1+ dot-pos))))
    (when (equal "" file-name)
      (error "AWS standard format handler does not contains filename: ~A"
	     handler-string))
    (with-standard-io-syntax
      (load file-name)
      (read-from-string symbol-name))))

(defun load-roswell-script (stream)
  "Loads a roswell script from STREAM and returns the main symbol."
  ;; The official loader of roswell script is `roswell:script'
  ;; function, but I think that is difficult to use.
  ;; I manually reads it to find the main function.
  (with-standard-io-syntax
    (loop with first-line = (read-line stream) ; skip the first line.
       initially
	 (assert (and (char= (char first-line 0) #\#)
		      (char= (char first-line 1) #\!))
		 () "No shebang in the roswell script: ~A" stream)
       with main-symbol = nil
       for form = (read stream nil 'eof)
       until (eq form 'eof)
       do (let ((val (eval form)))
	    (when (and (symbolp val) ; Checks whether the returned value is from `cl:defun'.
		       (string-equal (symbol-name val) "MAIN"))
	      (setf main-symbol val)))
       finally
	 (return main-symbol))))

(defun wrap-function-to-return-standard-output (function)
  "Makes a new function wrapping the passed one to returns a string
from characters written into `*standard-output*'"
  (lambda (&rest args)
    (with-output-to-string (*standard-output*)
      (apply function args))))

(defun find-handler-from-roswell-script (handler-string)
  "Tries to find a handler from Roswell script name.
 See `find-handler''s docstring"
  (let* ((main-symbol			; Find the main function
	  (with-open-file (in handler-string)
	    (load-roswell-script in)))
	 (func (alexandria:ensure-function main-symbol)))
    ;; Connect `*standard-output*' to AWS-lambda's return value.
    (wrap-function-to-return-standard-output func)))

(defun find-handler-from-lisp-forms (handler-string)
  "Tries to find a handler from lisp forms.
 See `find-handler''s docstring"
  (with-input-from-string (in handler-string)
    (with-standard-io-syntax
      (loop with ret
	 for form = (read in) then (read in nil 'eof)
	 until (eq form 'eof)
	 ;; I `eval' forms one-by-one because I want to affect it to subsequent forms.
	 do (setf ret (eval form))
	 finally
	   (return ret)))))

(defun string-suffix-p (suffix string)
  "Returns non-nil value when STRING ends with SUFFIX."
  (search suffix string
	  :start2 (- (length string) (length suffix))))

(defun find-handler (handler-string)
  "Find a handler from AWS-Lambda function's --handler parameter.
HANDLER-STRING is read as following:

* AWS Lambda's standard format: \"<file>.<method>\"

  Tries to `cl:load' the <file> and find a symbol denoted by <method>.
  <method> is read as a symbol. If no package marker, it is read in
  the `CL-USER' package.

* Roswell script file name.

  If HANDLER-STRING ends with \".ros\", tries to `cl:load' the file
  as a Roswell script. This runtime calls its main function with two
  args (data and headers) and returns the string written to
  `*standard-output*' as AWS-Lambda's result.

* Any number of Lisp forms.

  Otherwise, HANDLER-STRING is considered as a string contains Lisp forms.
  `find-handler' evaluates the forms in order with `cl:eval' (wow!),
  and uses the result of the last form.
  (Because AWS Lambda's 'handler' parameter cannot contain any spaces,
  you need very hacky codes.)"
  (assert (and handler-string
	       (not (equal handler-string ""))
	       (every #'graphic-char-p handler-string))
	  () "Invalid format for AWS Lambda function's handler: ~A" handler-string)
  (let* ((lisp-like?
	  (or (char= #\' (char handler-string 0))  ; If starts with quite, it is a quoted form.
	      (loop for c across handler-string
		 ;; If contains '()', I assume it is a Lisp form.
		 thereis (member c '(#\( #\))))))
	 (found-handler
	  (cond ((and (not lisp-like?)
		      (string-suffix-p ".ros" handler-string))
		 (find-handler-from-roswell-script handler-string))
		((and (not lisp-like?)
		      (find #\. handler-string))
		 (find-handler-from-aws-standard-format handler-string))
		(t
		 (find-handler-from-lisp-forms handler-string)))))
    (alexandria:ensure-function found-handler))) ; If not funcallble, raises an error.
