(in-package :thune)

(defvar *seen*)

(defhandler seen (socket message)
  (declare (ignore socket))
  (let* ((nick (nick (prefix message)))
         (cons (assoc nick *seen* :test #'string-equal)))
    (if cons
        (setf (cdr cons) message)
        (push (cons nick message) *seen*))))