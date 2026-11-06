;;; agent-shell-session-title-tests.el --- Session title tests -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests for prompt-derived fork titles and agent title updates.
;;

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'agent-shell)

(ert-deftest agent-shell-fork-title-uses-first-new-prompt-test ()
  "Test that the fork's first new prompt replaces its inherited title."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (let ((parent-state (agent-shell--make-state))
          (original-name (buffer-name))
          (events nil))
      (map-put! (map-elt parent-state :session) :title "Original topic")
      (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
      (map-put! (map-elt agent-shell--state :session) :title "Original topic")
      (map-put! agent-shell--state :fork-title-pending t)
      (agent-shell-subscribe-to
       :shell-buffer (current-buffer)
       :event 'session-title-changed
       :on-event (lambda (event) (push event events)))
      (agent-shell--seed-session-title
       (propertize "  Investigate the new approach  " 'face 'bold))
      (should (equal (map-nested-elt agent-shell--state '(:session :title))
                     "Investigate the new approach"))
      (should-not (map-elt agent-shell--state :fork-title-pending))
      (should-not (text-properties-at 0 (map-elt agent-shell--state :fork-title)))
      (should (equal (buffer-name)
                     (concat original-name " - Investigate the new approach")))
      (should (equal shell-maker--buffer-name-override (buffer-name)))
      (agent-shell--seed-session-title "A later prompt")
      (agent-shell--set-session-title "Original topic")
      (agent-shell--set-session-title "Agent-generated title")
      (should (equal (map-nested-elt agent-shell--state '(:session :title))
                     "Investigate the new approach"))
      (should (equal (buffer-name)
                     (concat original-name " - Investigate the new approach")))
      (should (equal (map-nested-elt parent-state '(:session :title))
                     "Original topic"))
      (should (= (length events) 1))
      (should (equal (map-nested-elt (car events) '(:data :title))
                     "Investigate the new approach")))))

(ert-deftest agent-shell-fork-title-waits-for-nonblank-prompt-test ()
  "Test that blank prompts do not consume the fork's pending title."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (dolist (prompt '("" " \n\t "))
      (agent-shell--seed-session-title prompt)
      (should (map-elt agent-shell--state :fork-title-pending))
      (should-not (map-nested-elt agent-shell--state '(:session :title)))
      (should-not (map-elt agent-shell--state :fork-title)))
    (agent-shell--seed-session-title "First real prompt")
    (should (equal (map-nested-elt agent-shell--state '(:session :title))
                   "First real prompt"))))

(ert-deftest agent-shell-session-title-preserves-normal-session-behavior-test ()
  "Test that non-fork sessions still accept agent-generated titles."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (agent-shell--seed-session-title (propertize "Initial prompt" 'face 'bold))
    (should (equal (map-nested-elt agent-shell--state '(:session :title))
                   "Initial prompt"))
    (should-not (text-properties-at
                 0 (map-nested-elt agent-shell--state '(:session :title))))
    (agent-shell--set-session-title "Agent summary")
    (agent-shell--seed-session-title "Next prompt")
    (should-not shell-maker--buffer-name-override)
    (should (equal (map-nested-elt agent-shell--state '(:session :title))
                   "Agent summary"))))

(ert-deftest agent-shell-fork-title-survives-pending-refresh-test ()
  "Test that an in-flight title refresh cannot restore the inherited name."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :client 'test-client)
    (map-put! agent-shell--state :supports-session-list t)
    (map-put! agent-shell--state :fork-title-pending t)
    (map-put! (map-elt agent-shell--state :session) :id "fork-id")
    (map-put! (map-elt agent-shell--state :session) :title "Original topic")
    (let ((requests 0)
          callback)
      (cl-letf (((symbol-function 'acp-send-request)
                 (lambda (&rest args)
                   (setq requests (1+ requests))
                   (setq callback (plist-get args :on-success)))))
        (agent-shell--refresh-session-title)
        (should (= requests 1))
        (agent-shell--seed-session-title "Fork's new direction")
        (funcall callback '((sessions . [((sessionId . "fork-id")
                                         (title . "Original topic"))])))
        (should (equal (map-nested-elt agent-shell--state '(:session :title))
                       "Fork's new direction"))
        (agent-shell--refresh-session-title)
        (should (= requests 1))))))

(ert-deftest agent-shell-send-command-seeds-fork-title-test ()
  "Test that submitting a fork prompt updates its title and sends the prompt."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (map-put! (map-elt agent-shell--state :session) :id "fork-id")
    (map-put! (map-elt agent-shell--state :session) :title "Original topic")
    (let ((agent-shell-show-busy-indicator nil)
          request)
      (cl-letf (((symbol-function 'agent-shell--send-request)
                 (lambda (&rest args) (setq request (plist-get args :request))))
                ((symbol-function 'agent-shell--append-transcript) #'ignore)
                ((symbol-function 'agent-shell-viewport--buffer)
                 (lambda (&rest _) nil)))
        (agent-shell--send-command :prompt "Try a different implementation"
                                    :shell-buffer (current-buffer)))
      (should (equal (map-nested-elt agent-shell--state '(:session :title))
                     "Try a different implementation"))
      (should (equal (map-nested-elt request '(:params sessionId)) "fork-id"))
      (should (equal (map-nested-elt request '(:params prompt))
                     [((type . "text") (text . "Try a different implementation"))])))))

(ert-deftest agent-shell-fork-buffer-name-normalizes-prompt-test ()
  "Test that multiline fork prompts produce short, single-line buffer names."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (let ((original-name (buffer-name)))
      (agent-shell--seed-session-title
       (concat "New topic\n\t" (make-string 60 ?x)))
      (should (equal (buffer-name)
                     (concat original-name " - New topic " (make-string 37 ?x) "..."))))))

(ert-deftest agent-shell-fork-buffer-name-keeps-viewport-test ()
  "Test that renaming a fork preserves its viewport and its contents."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (let* ((shell (current-buffer))
           (viewport (generate-new-buffer
                      (concat (buffer-name) agent-shell-viewport--suffix))))
      (unwind-protect
          (progn
            (with-current-buffer viewport
              (insert "Keep this draft"))
            (agent-shell--seed-session-title "New fork topic")
            (should (eq viewport (agent-shell-viewport--buffer
                                  :shell-buffer shell :existing-only t)))
            (should (eq shell (agent-shell-viewport--shell-buffer viewport)))
            (should (equal (with-current-buffer viewport (buffer-string))
                           "Keep this draft")))
        (kill-buffer viewport)))))

(ert-deftest agent-shell-fork-buffer-name-avoids-viewport-collision-test ()
  "Test that an unrelated viewport name cannot break the fork's association."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (let* ((shell (current-buffer))
           (viewport (generate-new-buffer
                      (concat (buffer-name) agent-shell-viewport--suffix)))
           (unrelated (generate-new-buffer
                       (concat (buffer-name) " - New topic"
                               agent-shell-viewport--suffix))))
      (unwind-protect
          (progn
            (agent-shell--seed-session-title "New topic")
            (should (eq viewport (agent-shell-viewport--buffer
                                  :shell-buffer shell :existing-only t)))
            (should (eq shell (agent-shell-viewport--shell-buffer viewport)))
            (should (buffer-live-p unrelated)))
        (kill-buffer viewport)
        (kill-buffer unrelated)))))

(ert-deftest agent-shell-fork-buffer-name-visible-in-switcher-test ()
  "Test that the switcher offers the renamed fork and selects its buffer."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (setq-local agent-shell--state (agent-shell--make-state :buffer (current-buffer)))
    (map-put! agent-shell--state :fork-title-pending t)
    (agent-shell--seed-session-title "Investigate another approach")
    (let ((shell (current-buffer))
          (agent-shell-show-config-icons nil)
          choices)
      (cl-letf (((symbol-function 'agent-shell-status)
                 (lambda (&rest _) 'ready))
                ((symbol-function 'completing-read)
                 (lambda (_prompt collection &rest _)
                   (setq choices (all-completions "" collection))
                   (seq-first choices))))
        (should (eq shell (agent-shell--read-shell-buffer :buffers (list shell)))))
      (should (string-prefix-p (buffer-name) (seq-first choices))))))

(provide 'agent-shell-session-title-tests)

;;; agent-shell-session-title-tests.el ends here
