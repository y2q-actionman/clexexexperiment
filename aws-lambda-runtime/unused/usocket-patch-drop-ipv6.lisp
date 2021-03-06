;;; To avoid failures of socket(2) on EPERM, I drop IPv6 support.
;;; Please see:
;;; https://blog.marshallbrekka.com/post/2016-06-10/erlang-on-aws-lambda/
;;;
;;; This code is only for SBCL.

(in-package :aws-lambda-runtime)

(defvar *original-get-host-by-name* nil)

(defun get-hosts-by-name-and-remove-ipv6 (name)
  "Calls the original `usocket:get-hosts-by-name' (via `*original-get-host-by-name*')
and removes IPv6 addresses, for supress making IPv6 sockets."
  (loop with all-addrs = (funcall *original-get-host-by-name* name)
     for addr in all-addrs
     unless (= 16 (length addr))	; see usocket's sbcl code.
     collect addr into ret
     finally
       (let ((*print-pretty* nil))
	 (format *debug-io* "~&addrs ~A -> ~A~%" all-addrs ret))
       (return ret)))

(defun patch-get-hosts-by-name ()
  "Replace `usocket:get-hosts-by-name' with our `get-hosts-by-name-and-remove-ipv6'"
  (unless *original-get-host-by-name*
    (setf *original-get-host-by-name*
	  (fdefinition 'usocket::get-hosts-by-name)))
  (shiftf (fdefinition 'usocket::get-hosts-by-name)
	  (fdefinition 'get-hosts-by-name-and-remove-ipv6)))

;; To drop IPv6 support, call `patch-get-hosts-by-name' at the
;; initialization phase in `bootstrap'.
