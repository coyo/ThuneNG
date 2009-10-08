(in-package :thune)

(defvar *commands* ())

(defun command-args (message)
  (when (or (string= "PRIVMSG" (command message))
            (string= "NOTICE" (command message)))
    (let* ((string (car (last (parameters message))))
           (first-space (position #\Space string))
           (nick (conf-value "nick")))
      (cond
        ((char= (aref (conf-value "cmdchar") 0)
                (aref string 0))
         (if first-space
             (values (string-trim " " (subseq string (1+ first-space)))
                     (subseq string 1 first-space))
             (values ""
                     (subseq string 1))))
        ((and (> (length string) (length nick))
          (string= nick (subseq string 0 (length nick))))
         (when first-space
           (let ((second-space (position #\Space string
                                         :start (1+ first-space))))
             (if second-space
                 (values (string-trim " " (subseq string (1+ second-space)))
                         (subseq string (1+ first-space) second-space))
                 (values ""
                         (subseq string (1+ first-space)))))))))))

(defun add-command (name function)
  (let ((current (assoc name *commands*
                        :test #'string-equal)))
    (if current
        (setf (cdr current) function)
        (push (cons name function) *commands*)))
  *commands*)

(defun find-command (name)
  (cdr (assoc name *commands* :test #'string-equal)))

(defmacro defcommand (name args &body body)
  (let ((func-name (intern (concatenate 'string
                                        "COMMAND-"
                                        (string-upcase name)))))
    `(progn
       (defun ,func-name ,args ,@body)
       (add-command ,name (quote ,func-name)))))

;; TODO: Parallelize command execution
(defhandler command-launcher (socket message)
  (multiple-value-bind (args command-name) (command-args message)
    (declare (ignore args))
    (let ((command (find-command command-name)))
      (when command
        (handler-case
            (funcall command socket message)
          (error (e)
            (send socket (reply-to message (format nil "Error executing command ~a: ~a" command-name e)))))))))