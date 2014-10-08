;; Debugging the compiler. -*- lexical-binding:t -*-

(defgeneric elcomp--pp (obj verbose)
  "FIXME")

(defmethod elcomp--pp (obj verbose)
  (error "unrecognized instruction"))

(defmethod elcomp--pp (obj verbose)
  (princ obj))

;; FIXME eldoc for defmethod is messed up
(defmethod elcomp--pp ((obj elcomp--set) verbose)
  (if verbose
      (progn
	(princ "set ")
	(elcomp--pp (oref obj :sym) nil)
	(princ " = ")
	(elcomp--pp (oref obj :value) nil))
    (elcomp--pp (oref obj :sym) nil)))

(defmethod elcomp--pp ((obj elcomp--call) verbose)
  (if verbose
      (progn
	(princ "call ")
	(elcomp--pp (oref obj :sym) nil)
	(princ " = ")
	(elcomp--pp (oref obj :func) nil)
	(when (oref obj :args)
	  (let ((first t))
	    (dolist (arg (oref obj :args))
	      (princ (if first "(" " "))
	      (setf first nil)
	      (elcomp--pp arg nil))
	    (princ ")"))))
    (elcomp--pp (oref obj :sym) nil)))

(defmethod elcomp--pp ((obj elcomp--goto) verbose)
  (princ "goto BB ")
  (princ (elcomp--basic-block-number (oref obj :block))))

(defmethod elcomp--pp ((obj elcomp--if) verbose)
  (princ "if ")
  (elcomp--pp (oref obj :sym) nil)
  (princ " BB ")
  (princ (elcomp--basic-block-number (oref obj :block-true)))
  (princ " else BB ")
  (princ (elcomp--basic-block-number (oref obj :block-false))))

(defmethod elcomp--pp ((obj elcomp--return) verbose)
  (princ "return ")
  (elcomp--pp (oref obj :sym) nil))

(defmethod elcomp--pp ((obj elcomp--constant) verbose)
  (princ "<< ")
  (princ (oref obj :value))
  (princ " >>"))

(defmethod elcomp--pp ((obj elcomp--phi) verbose)
  (princ "ϕ:")
  (princ (oref obj :original-name))
  (when verbose
    (princ " =")
    (maphash (lambda (item _ignore)
	       (princ " ")
	       (elcomp--pp item nil))
	     (oref obj :args))))

(defmethod elcomp--pp ((obj elcomp--argument) verbose)
  (princ "argument ")
  (princ (oref obj :original-name)))

(defmethod elcomp--pp ((obj elcomp--catch) verbose)
  (princ "catch ")
  (elcomp--pp (oref obj :result) nil)
  (princ " = ")
  (princ (oref obj :tag))
  (princ " => BB ")
  (princ (elcomp--basic-block-number (oref obj :handler))))

(defmethod elcomp--pp ((obj elcomp--condcase) verbose)
  (princ "condition-case ")
  (elcomp--pp (oref obj :variable) nil)
  (princ ", ")
  (princ (oref obj :condition-name))
  (princ " => BB ")
  (princ (elcomp--basic-block-number (oref obj :handler))))

(defmethod elcomp--pp ((obj elcomp--unwind-protect) verbose)
  (princ "unwind-protect => BB ")
  (princ (elcomp--basic-block-number (oref obj :handler))))

(defun elcomp--pp-insn (text insn verbose)
  (princ text)
  (princ " ")
  (elcomp--pp insn verbose)
  (princ "\n"))

(defun elcomp--pp-basic-block (bb)
  (princ (format "\n[BB %d"
		 (elcomp--basic-block-number bb)))
  (when (> (hash-table-count (elcomp--basic-block-parents bb)) 0)
    (princ " (parents:")
    (maphash (lambda (parent-bb _ignore)
	       (princ (format " %d" (elcomp--basic-block-number parent-bb))))
	     (elcomp--basic-block-parents bb))
    (princ ")"))
  (princ (format " (idom: %d)"
		 (elcomp--basic-block-number
		  (elcomp--basic-block-immediate-dominator bb))))
  (princ "]\n")
  (dolist (exception (elcomp--basic-block-exceptions bb))
    (princ "    ")
    (elcomp--pp exception (current-buffer))
    (princ "\n"))
  (maphash (lambda (_ignore_name phi)
	     (princ "    ")
	     (elcomp--pp phi t)
	     (princ "\n"))
	   (elcomp--basic-block-phis bb))
  (dolist (item (elcomp--basic-block-code bb))
    (elcomp--pp item (current-buffer))
    (princ "\n")))

(defun elcomp--pp-compiler (compiler)
  (elcomp--iterate-over-bbs compiler #'elcomp--pp-basic-block))

;; Temporary function for hacking.
(defun elcomp--do (form)
  (let ((buf (get-buffer-create "*ELCOMP*")))
    (with-current-buffer buf
      (erase-buffer)
      ;; Use "let*" so we can hack debugging prints into the compiler
      ;; and have them show up in the temporary buffer.
      (let* ((standard-output buf)
	     (compiled-form (elcomp--translate form)))
	(elcomp--pp-compiler compiled-form))
      (pop-to-buffer buf))))
