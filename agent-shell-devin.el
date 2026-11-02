;;; agent-shell-devin.el --- Devin agent configurations -*- lexical-binding: t; -*-

;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This package is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This file includes Devin CLI configurations using `devin acp'.
;; Authenticate with `devin auth login' before starting a shell.
;;

;;; Code:

(eval-when-compile
  (require 'cl-lib))
(require 'shell-maker)
(require 'acp)

(declare-function agent-shell--indent-string "agent-shell")
(declare-function agent-shell-welcome-message "agent-shell")
(declare-function agent-shell-make-agent-config "agent-shell")
(autoload 'agent-shell-make-agent-config "agent-shell")
(declare-function agent-shell--make-acp-client "agent-shell")
(declare-function agent-shell--dwim "agent-shell")

(defcustom agent-shell-devin-acp-command
  '("devin" "acp")
  "Command and parameters for the Devin CLI ACP server.

The first element is the command name, and the rest are command parameters.
For example, use \\='(\"devin\" \"acp\" \"--model\" \"opus\") to select a model,
or \\='(\"devin\" \"acp\" \"--cloud\") to use Devin Cloud."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-devin-environment
  nil
  "Environment variables for the Devin CLI ACP server.

This should be a list of environment variables to be used when
starting the Devin CLI ACP server, for example \\='(\"DEVIN_MODEL=opus\")."
  :type '(repeat string)
  :group 'agent-shell)

(defun agent-shell-devin-make-agent-config ()
  "Create a Devin agent configuration.

Returns an agent configuration alist using `agent-shell-make-agent-config'."
  (agent-shell-make-agent-config
   :identifier 'devin
   :mode-line-name "Devin"
   :buffer-name "Devin"
   :shell-prompt "Devin> "
   :shell-prompt-regexp "Devin> "
   :welcome-function #'agent-shell-devin--welcome-message
   :icon-name "devin.png"
   :client-maker (lambda (buffer)
                   (agent-shell-devin-make-client :buffer buffer))
   :install-instructions
   "Install Devin CLI (see https://devin.ai), then run `devin auth login`."))

;;;###autoload
(defun agent-shell-devin-start-agent ()
  "Start an interactive Devin agent shell."
  (interactive)
  (agent-shell--dwim :config (agent-shell-devin-make-agent-config)
                     :new-shell t))

(cl-defun agent-shell-devin-make-client (&key buffer)
  "Create a Devin ACP client with BUFFER as context.

Uses the CLI's existing login from `devin auth login'."
  (unless buffer
    (error "Missing required argument: :buffer"))
  (agent-shell--make-acp-client :command (car agent-shell-devin-acp-command)
                                :command-params (cdr agent-shell-devin-acp-command)
                                :environment-variables agent-shell-devin-environment
                                :context-buffer buffer))

(defun agent-shell-devin--welcome-message (config)
  "Return Devin welcome message using `shell-maker' CONFIG."
  (let ((art (agent-shell--indent-string 4 (agent-shell-devin--ascii-art)))
        (message (agent-shell-welcome-message config)))
    (concat "\n\n"
            art
            "\n\n"
            message)))

(defun agent-shell-devin--ascii-art ()
  "Return Devin ASCII art with theme-appropriate fixed-pitch styling."
  (let ((is-dark (eq (frame-parameter nil 'background-mode) 'dark))
        (text (string-trim "
░░░░░     ░░░░░░░   ░░   ░░   ░░░   ░░   ░░
░░   ░░   ░░        ░░   ░░   ░░░   ░░░  ░░
░░   ░░   ░░        ░░   ░░   ░░░   ░░░░ ░░
░░   ░░   ░░░░░░    ░░   ░░   ░░░   ░░ ░░░░
░░   ░░   ░░         ░░ ░░    ░░░   ░░  ░░░
░░   ░░   ░░          ░░░     ░░░   ░░   ░░
░░░░░     ░░░░░░░      ░      ░░░   ░░   ░░
" "\n")))
    (propertize text 'font-lock-face (if is-dark
                                         '(:foreground "#8b949e" :inherit fixed-pitch)
                                       '(:foreground "#444" :inherit fixed-pitch)))))

(provide 'agent-shell-devin)

;;; agent-shell-devin.el ends here
