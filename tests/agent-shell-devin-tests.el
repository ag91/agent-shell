;;; agent-shell-devin-tests.el --- Tests for agent-shell-devin -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests for Devin configuration and ACP client creation.
;;

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'agent-shell)
(require 'agent-shell-devin)

(ert-deftest agent-shell-devin-make-agent-config-test ()
  "Test that Devin config has its own identity and prompt."
  (let ((config (agent-shell-devin-make-agent-config)))
    (should (eq (map-elt config :identifier) 'devin))
    (should (equal (map-elt config :mode-line-name) "Devin"))
    (should (equal (map-elt config :buffer-name) "Devin"))
    (should (equal (map-elt config :shell-prompt) "Devin> "))
    (should (equal (map-elt config :shell-prompt-regexp) "Devin> "))
    (should (equal (map-elt config :icon-name) "devin.png"))
    (should (eq (map-elt config :welcome-function)
                #'agent-shell-devin--welcome-message))
    (should-not (map-elt config :needs-authentication))))

(ert-deftest agent-shell-devin-registered-test ()
  "Test that Devin is available in the default agent picker."
  (should (memq #'agent-shell-devin-make-agent-config
                (agent-shell-default-agent-config-makers)))
  (let ((agent-shell-agent-configs (agent-shell-default-agent-config-makers)))
    (should (seq-find (lambda (config)
                        (eq (map-elt config :identifier) 'devin))
                      (agent-shell--resolved-agent-configs)))))

(ert-deftest agent-shell-devin-make-client-default-command-test ()
  "Test that the default client runs Devin's stdio ACP server."
  (let ((agent-shell-devin-acp-command '("devin" "acp"))
        (agent-shell-devin-environment nil))
    (cl-letf (((symbol-function 'agent-shell--make-acp-client)
               (lambda (&rest args) args)))
      (with-temp-buffer
        (let ((client (funcall (map-elt (agent-shell-devin-make-agent-config)
                                        :client-maker)
                               (current-buffer))))
          (should (equal client
                         (list :command "devin"
                               :command-params '("acp")
                               :environment-variables nil
                               :context-buffer (current-buffer)))))))))

(ert-deftest agent-shell-devin-make-client-custom-command-test ()
  "Test that custom command arguments and environment reach the client."
  (let ((agent-shell-devin-acp-command '("/custom/devin" "acp" "--cloud"))
        (agent-shell-devin-environment '("DEVIN_MODEL=opus")))
    (cl-letf (((symbol-function 'agent-shell--make-acp-client)
               (lambda (&rest args) args)))
      (with-temp-buffer
        (should (equal (agent-shell-devin-make-client :buffer (current-buffer))
                       (list :command "/custom/devin"
                             :command-params '("acp" "--cloud")
                             :environment-variables '("DEVIN_MODEL=opus")
                             :context-buffer (current-buffer))))))))

(ert-deftest agent-shell-devin-make-client-requires-buffer-test ()
  "Test that creating a Devin client requires a context buffer."
  (should-error (agent-shell-devin-make-client)
                :type 'error))

(ert-deftest agent-shell-devin-start-agent-test ()
  "Test that the interactive command requests a new Devin shell."
  (cl-letf (((symbol-function 'agent-shell--dwim)
             (lambda (&rest args) args)))
    (let ((args (call-interactively #'agent-shell-devin-start-agent)))
      (should (eq (map-elt (plist-get args :config) :identifier) 'devin))
      (should (eq (plist-get args :new-shell) t)))))

(ert-deftest agent-shell-devin-ascii-art-test ()
  "Test that the banner is aligned and styled for both theme backgrounds."
  (dolist (mode '(dark light))
    (cl-letf (((symbol-function 'frame-parameter)
               (lambda (&rest _) mode)))
      (let* ((art (agent-shell-devin--ascii-art))
             (lines (split-string art "\n"))
             (face (get-text-property 0 'font-lock-face art)))
        (should (= (length lines) 7))
        (should (seq-every-p (lambda (line)
                              (= (string-width line)
                                 (string-width (seq-first lines))))
                            lines))
        (should (eq (plist-get face :inherit) 'fixed-pitch))
        (should (equal (plist-get face :foreground)
                       (if (eq mode 'dark) "#8b949e" "#444")))))))

(ert-deftest agent-shell-devin-welcome-message-test ()
  "Test that the welcome message prefixes the banner and preserves CONFIG."
  (let ((config (agent-shell-devin-make-agent-config)))
    (cl-letf (((symbol-function 'agent-shell-welcome-message)
               (lambda (received-config)
                 (should (eq received-config config))
                 "Session information")))
      (should (equal (funcall (map-elt config :welcome-function) config)
                     (concat "\n\n"
                             (agent-shell--indent-string
                              4 (agent-shell-devin--ascii-art))
                             "\n\nSession information"))))))

(provide 'agent-shell-devin-tests)

;;; agent-shell-devin-tests.el ends here
