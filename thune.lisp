(in-package :thune)

(defun register (channel)
  (send channel (make-message "NICK" (conf-value "nick")))
  (send channel (make-message "USER"
                              (conf-value "user")
                              "." "."
                              (conf-value "realname"))))

(defhandler pong (socket message)
  (when (string= (command message) "PING")
    (setf (command message) "PONG")
    (send socket message)))

(define-condition disable-reconnect () ())

(defun start ()
  "Launches the bot."
  (sanify-output)
  (setf drakma:*drakma-default-external-format* :utf-8)
  (setf %thread-pool-soft-limit 64)
  (load-conf "thune.conf")
  (let ((socket)
        (input (make-instance 'channel))
        (output (make-instance 'unbounded-channel))
        (ignore (conf-list (conf-value "ignore")))
        (reconnect t)
        (die nil))
    (format t "Connecting...~%")
    (pexec ()
      (loop
         (setf socket (connect (conf-value "server")))
         (format t "Connected.~%")
         (register output)
         (handler-case
             (loop
                (let ((message))
                  (setf message (get-message socket))
                  (unless (and (typep (prefix message) 'user)
                               (some (lambda (x)
                                       (string-equal x (nick (prefix message))))
                                     ignore))
                    (send input message))))
           (end-of-file ()
             (format t "Disconnected.~%")
             (if reconnect
                 (format t "Reconnecting...~%")
                 (progn
                   (setf die t)
                   (return)))))))
    (pexec ()
      (handler-bind
          ((disable-reconnect
            (lambda (condition)
              (declare (ignore condition))
              (setf reconnect nil)))
           (error
            (lambda (e)
              (send output (make-message "QUIT" (format nil "Error: ~a" e))))))
        (loop
           (let ((message (recv input)))
             (if message
                 (progn (format t "-> ~a~%" (message->string message))
                        (call-handlers output message))
                 (return))))))
    (loop until die do
         (let ((message (recv output)))
           (send-message socket message)
           (format t "<- ~a~%" (message->string message))))))

(defun start-background ()
  (pcall #'start))