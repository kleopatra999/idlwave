;;; idlw-help.el --- Help code and topics for IDLWAVE
;; Copyright (c) 2000 Carsten Dominik
;; Copyright (c) 2001, 2002 J.D.Smith
;;
;; Author: Carsten Dominik <dominik@astro.uva.nl>
;; Maintainer: J.D. Smith <jdsmith@as.arizona.edu>
;; Version: VERSIONTAG

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; The constants which contain the topics information for IDLWAVE's
;; online help feature.  This information is extracted automatically from
;; the IDL documentation.
;;
;;; INSERT-CREATED-BY-HERE
;;
;; New versions of IDLWAVE, documentation, and more information
;; available from:
;;                 http://idlwave.org
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Code:


(defvar idlwave-completion-help-info)
(defvar idlwave-help-use-dedicated-frame)
(defvar idlwave-help-frame-parameters)

(defvar idlwave-help-frame nil
  "The frame for display of IDL online help.")
(defvar idlwave-help-frame-width 102
  "The default width of the help frame.")

(defvar idlwave-help-file nil
  "The file containing the ASCII help for IDLWAVE.")

(defvar idlwave-help-topics nil
  "List of helptopics and byte positions in `idlw-help.txt'.")

(defvar idlwave-help-current-topic nil
  "The topic currently loaded into the IDLWAVE Help buffer.")

(defvar idlwave-help-mode-line-indicator ""
  "Used for the special mode line in the idlwave-help-mode.")

(defvar idlwave-help-window-configuration nil)
(defvar idlwave-help-name-translations nil)   ; defined by get_rinfo
(defvar idlwave-help-alt-names nil)           ; defined by get_rinfo
(defvar idlwave-help-special-topic-words)     ; defined by get_rinfo

(defvar idlwave-help-stack-back nil
  "Help topic stack for backwards motion.")
(defvar idlwave-help-stack-forward nil
  "Help topic stack for forward motion. 
Only gets populated when moving back.")

;; Define the key bindings for the Help application

(defvar idlwave-help-mode-map (make-sparse-keymap)
  "The keymap used in idlwave-help-mode.")

(define-key idlwave-help-mode-map "q" 'idlwave-help-quit)
(define-key idlwave-help-mode-map "w" 'widen)
(define-key idlwave-help-mode-map "\C-m" (lambda (arg)
					   (interactive "p")
					   (scroll-up arg)))
(define-key idlwave-help-mode-map "n" 'idlwave-help-next-topic)
(define-key idlwave-help-mode-map "p" 'idlwave-help-previous-topic)
(define-key idlwave-help-mode-map " " 'scroll-up)
(define-key idlwave-help-mode-map [delete] 'scroll-down)
(define-key idlwave-help-mode-map "b" 'idlwave-help-back)
(define-key idlwave-help-mode-map "f" 'idlwave-help-forward)
(define-key idlwave-help-mode-map "c" 'idlwave-help-clear-history)
(define-key idlwave-help-mode-map "o" 'idlwave-online-help)
(define-key idlwave-help-mode-map "*" 'idlwave-help-load-entire-file)
(define-key idlwave-help-mode-map "h" 'idlwave-help-find-header)
(define-key idlwave-help-mode-map "H" 'idlwave-help-find-first-header)
(define-key idlwave-help-mode-map "L" 'idlwave-help-activate-aggressively)
(define-key idlwave-help-mode-map "." 'idlwave-help-toggle-header-match-and-def)
(define-key idlwave-help-mode-map "F" 'idlwave-help-fontify)
(define-key idlwave-help-mode-map "\M-?" 'idlwave-help-return-to-calling-frame)
(define-key idlwave-help-mode-map "x" 'idlwave-help-return-to-calling-frame)

;; Define the menu for the Help application

(easy-menu-define
 idlwave-help-menu idlwave-help-mode-map
 "Menu for Help IDLWAVE system"
 '("IDLHelp"
   ["Open topic" idlwave-online-help t]
   ["History: Backward" idlwave-help-back t]
   ["History: Forward" idlwave-help-forward t]
   ["History: Clear" idlwave-help-clear-history t]
   "---"
   ["Follow Link" idlwave-help-follow-link (not idlwave-help-is-source)]
   ["Browse: Next Topic" idlwave-help-next-topic (not idlwave-help-is-source)]
   ["Browse: Previous Topic" idlwave-help-previous-topic
    (not idlwave-help-is-source)]
   ["Load Entire Help File" idlwave-help-load-entire-file t]
   "---"
   ["Definition <-> Help Text" idlwave-help-toggle-header-match-and-def
    idlwave-help-is-source]
   ["Find DocLib Header" idlwave-help-find-header idlwave-help-is-source]
   ["Find First DocLib Header" idlwave-help-find-first-header
    idlwave-help-is-source]
   ["Fontify help buffer" idlwave-help-fontify idlwave-help-is-source]
   "--"
   ["Quit" idlwave-help-quit t]))

(defun idlwave-help-mode ()
  "Major mode for displaying IDL Help.

This is a VIEW mode for the ASCII version of IDL Help files,
with some extras.  Its main purpose is speed - so don't
expect a fully hyper-linked help.

Scrolling:          SPC  DEL  RET
Topic Histrory:     [b]ackward   [f]orward
Topic Browsing:     [n]ext       [p]revious
Choose new Topic:   [o]pen
Follow Link:        Mouse button 2 finds help on word at point
Text Searches:      Inside Topic: Use Emacs search functions
                    Global:  Press `*' to load entire help file
Exit:               [q]uit or mouse button 3 will kill the frame

When the hep text is a source file, the following commands are available

Fontification:      [F]ontify the buffer like source code
Jump:               [h] to function doclib header
                    [H] to file doclib header
                    [.] back and forward between header and definition

Here are all keybindings.
\\{idlwave-help-mode-map}"
  (kill-all-local-variables)
  (buffer-disable-undo)
  (setq major-mode 'idlwave-help-mode
	mode-name "IDLWAVE Help")
  (use-local-map idlwave-help-mode-map)
  (easy-menu-add idlwave-help-menu idlwave-help-mode-map)
  (setq truncate-lines t)
  (setq case-fold-search t)
  (setq mode-line-format
	(list ""
	      'mode-line-modified
	      'mode-line-buffer-identification
	      ":  " 'idlwave-help-mode-line-indicator
	      " -%-"))
  (setq buffer-read-only t)
  (set (make-local-variable 'idlwave-help-def-pos) nil)
  (set (make-local-variable 'idlwave-help-args) nil)
  (set (make-local-variable 'idlwave-help-in-header) nil)
  (set (make-local-variable 'idlwave-help-is-source) nil)
  (run-hooks 'idlwave-help-mode-hook))

(defvar idlwave-current-obj_new-class)
(defvar idlwave-help-diagnostics)
(defvar idlwave-experimental)
(defvar idlwave-last-context-help-pos)
(defun idlwave-do-context-help (&optional arg)
  "Wrapper around the call to idlwave-context-help1.
It collects and prints the diagnostics messages."
  (let ((marker (list (current-buffer) (point)))
	(idlwave-help-diagnostics nil))
    ;; Check for frame switching.  When the command is invoked twice
    ;; at the same position, we try to switch to the help frame
    ;; FIXME:  Frame switching works only on XEmacs
    (if (and idlwave-experimental
	     (equal last-command this-command)
	     (equal idlwave-last-context-help-pos marker))
	(idlwave-help-select-help-frame)
      ;; Do the real thing.
      (setq idlwave-last-context-help-pos marker)
      (idlwave-do-context-help1 arg)
      (if idlwave-help-diagnostics
	  (message "%s" (mapconcat 'identity 
				   (nreverse idlwave-help-diagnostics)
				   "; "))))))


(defvar idlwave-help-do-class-struct-tag nil)
(defvar idlwave-help-do-struct-tag nil)
(defun idlwave-do-context-help1 (&optional arg)
  "The work-horse version of `idlwave-context-help', which see."
  (save-excursion
    (if (equal (char-after) ?/) 
	(forward-char 1)
      (if (equal (char-before) ?=)
	  (backward-char 1)))
    (let* ((idlwave-query-class nil)
	   (idlwave-force-class-query (equal arg '(4)))
	   (chars "a-zA-Z0-9_$.!")
	   (beg (save-excursion (skip-chars-backward chars) (point)))
	   (end (save-excursion (skip-chars-forward chars) (point)))
	   (this-word (buffer-substring beg end))
	   (st-ass (assoc (downcase this-word) idlwave-help-special-topic-words))
	   (classtag (and (string-match "self\\." this-word)
			  (< beg (- end 4))))
	   (structtag (and (fboundp 'idlwave-complete-structure-tag)
			   (string-match "\\`\\([^.]*\\)\\." this-word)
			   (< beg (- end 4))))
	   module keyword cw mod1 mod2 mod3)
      (if (or arg 
	      (and (not st-ass)
		   (not classtag)
		   (not structtag)
		   (not (member (string-to-char this-word) '(?! ?.)))))
	  ;; Need the module information
	  (progn
	    (setq module (idlwave-what-module-find-class)
		  cw (nth 2 (idlwave-where)))
	    ;; Correct for OBJ_NEW, we may need an INIT method instead.
	    (if (equal (idlwave-downcase-safe (car module)) "obj_new")
		(let* ((bos (save-excursion (idlwave-beginning-of-statement)
					    (point)))
		       (str (buffer-substring bos (point))))
		  (if (string-match "OBJ_NEW([ \t]*['\"]\\([a-zA-Z][a-zA-Z0-9$_]+\\)['\"]"
				    str)
		      (setq module (list "init" 'fun (match-string 1 str))
			    idlwave-current-obj_new-class (match-string 1 str))
		    )))))
      (cond (arg (setq mod1 module))
	    ;; A special topic
	    (st-ass (setq mod1 (list (or (cdr st-ass) (car st-ass)) 
				     nil nil nil)))
	    
	    ;; A system variable
	    ((string-match "\\`![a-zA-Z0-9_]+" this-word)
	     (setq mod1 (list "system variables" nil nil
			      (match-string 0 this-word))))

	    ;; An executive command
	    ((string-match "^\\." this-word)
	    (setq mod1 (list this-word nil nil nil)))

	    ;; A class
	    ((and (eq cw 'class)
		  (or (idlwave-in-quote)  ; e.g. obj_new
		      (re-search-backward "\\<inherits[ \t]+[A-Za-z0-9_]*\\="
					  (max (point-min) (- (point) 40)) t)))
	     ;; Class completion inside string delimiters should be
	     ;; the class inside OBJ_NEW.
	     (setq mod1 (list nil nil this-word nil)))

	    ;; A class structure tag (self.BLAH)
	    (classtag
	     (let ((tag (substring this-word (match-end 0)))
		   class-with)
	       (when (setq class-with 
			   (idlwave-class-or-superclass-with-tag
			    (nth 2 (idlwave-current-routine))
			    tag))
		 (if (assq (idlwave-sintern-class class-with) 
			   idlwave-system-class-info)
		     (error "No help available for system class tags."))
		 (setq idlwave-help-do-class-struct-tag t)
		 (setq mod1 (list (concat class-with "__define")
				  'pro
				  nil ; no class.... it's a procedure!
				  tag)))))

	    ;; A regular structure tag (only if complete-structtag loaded).
	    (structtag
	     (let ((var (match-string 1 this-word))
		   (tag (substring this-word (match-end 0))))
	       ;; Check if we need to update the "current" structure
	       (idlwave-prepare-structure-tag-completion var)
	       (setq idlwave-help-do-struct-tag
		     idlwave-structtag-struct-location
		     mod1 (list nil nil nil tag))))
	    
	    ;; A routine keyword
	    ((and (memq cw '(function-keyword procedure-keyword))
		  (stringp this-word)
		  (string-match "\\S-" this-word)
		  (not (string-match "!" this-word)))
	     (cond ((or (= (char-before beg) ?/)
			(save-excursion (goto-char end)
					(looking-at "[ \t]*=")))
		    ;; Certainly a keyword. Check for abbreviation etc.
		    (setq keyword (idlwave-expand-keyword this-word module))
		    (cond
		     ((null keyword)
		      (idlwave-help-diagnostics
		       (format "%s does not accept `%s' kwd"
			       (idlwave-make-full-name (nth 2 module)
						       (car module))
			       (upcase this-word))
		       'ding))
		     ((consp keyword)
		      (idlwave-help-diagnostics
		       (format "%d matches for kwd abbrev `%s'"
			       (length keyword) this-word)
		       'ding)
		      ;; We continue anyway with the first match...
		      (setq keyword (car keyword))))
		    (setq mod1 (append module (list keyword)))
		    (setq mod2 module))
		   ((equal (char-after end) ?\()
		    ;; A function - what-module will have caught this
		    (setq mod1 module))
		   (t
		    ;; undecided - try function, keyword, then enclosing mod.
		    ;; Check for keyword abbreviations, but do not report
		    ;; errors, because it might something else.
		    ;; FIXME: is this a good way to handle this?
		    (setq keyword (idlwave-expand-keyword this-word module))
		    (if (consp keyword) (setq keyword (car keyword)))
		    (setq mod1 (append module (list keyword))
			  mod2 (list this-word 'fun nil)
			  mod3 module))))

	    ;; Everything else
	    (t
	     (setq mod1 module)))
      (if mod3
	  (condition-case nil
	      (apply 'idlwave-online-help nil mod1)
	    (error (condition-case nil
		       (apply 'idlwave-online-help nil mod2)
		     (error (apply 'idlwave-online-help nil mod3)))))
	(if mod2
	    (condition-case nil
		(apply 'idlwave-online-help nil mod1)
	      (error (apply 'idlwave-online-help nil mod2)))
	  (if mod1
	      (apply 'idlwave-online-help nil mod1)
	    (error "Don't know which item to show help for.")))))))

(defvar idlwave-extra-help-function)
(defun idlwave-do-mouse-completion-help (ev)
  "Display online help on n item in the *Completions* buffer.
Need additional info stored in `idlwave-completion-help-info'."
  (let* ((cw (selected-window))
	 (info idlwave-completion-help-info)
	 (what (nth 0 info))
	 (name (nth 1 info))
	 (type (nth 2 info))
	 (class (nth 3 info))
	 (need-class class)
	 (kwd (nth 4 info))
	 (sclasses (nth 5 info))
	 word)
    (mouse-set-point ev)
    (setq word (idlwave-this-word))
    (select-window cw)
    (cond ((memq what '(procedure function routine))
	   (setq name word)
	   (if (or (eq class t)
		   (and (stringp class) sclasses))
	       (let* ((classes (idlwave-all-method-classes
			       (idlwave-sintern-method name)
			       type)))
		 (if sclasses
		     (setq classes (idlwave-members-only 
				    classes (cons class sclasses))))
		 (if (not idlwave-extra-help-function)
		     (setq classes (idlwave-grep-help-topics classes)))
		 (setq class (idlwave-popup-select ev classes 
						   "Select Class" 'sort))))
	   (if (stringp class)
	       (setq class (idlwave-find-inherited-class
			    (idlwave-sintern-routine-or-method name class)
			    type (idlwave-sintern-class class)))))
	  ((eq what 'keyword)
	   (setq kwd word)
	   (if (or (eq class t)
		   (and (stringp class) sclasses))
	       (let ((classes  (idlwave-all-method-keyword-classes
				(idlwave-sintern-method name)
				(idlwave-sintern-keyword kwd)
				type)))
		 (if sclasses
		     (setq classes (idlwave-members-only 
				    classes (cons class sclasses))))
		 (if (not idlwave-extra-help-function)
		     (setq classes (idlwave-grep-help-topics classes)))
		 (setq class (idlwave-popup-select ev classes
						   "Select Class" 'sort))))
	   (if (stringp class)
	       (setq class (idlwave-find-inherited-class
			    (idlwave-sintern-routine-or-method name class)
			    type (idlwave-sintern-class class)))))
	  ((eq what 'class)
	   (setq class word))
	  ((and (symbolp what)  ;; FIXME:  document this.
		(fboundp what))
	   (funcall what 'set word))
	  (t (error "Cannot help with this item")))
    (if (and need-class (not class))
	(error "Cannot help with this item"))
    (idlwave-online-help nil name type class kwd)))

(defvar idlwave-highlight-help-links-in-completion)
(defun idlwave-highlight-linked-completions ()
  "Highlight all completions for which help is available.
`idlwave-help-link-face' is used for this."
  (if idlwave-highlight-help-links-in-completion      
      (save-excursion
	(set-buffer (get-buffer "*Completions*"))
	(save-excursion
	  (let* ((case-fold-search t)
		 (props (list 'face 'idlwave-help-link-face))
		 (info idlwave-completion-help-info)
		 (what (nth 0 info))
		 (name (nth 1 info))
		 (type (nth 2 info))
		 (class (nth 3 info))
		 ;; (kwd (nth 4 info))
		 (sclasses (nth 5 info))
		 (kwd-doit
		  (and (eq what 'keyword)
		       (if (equal (idlwave-downcase-safe name) "obj_new")
			   (idlwave-is-help-topic
			    (idlwave-make-full-name
			     idlwave-current-obj_new-class "Init"))
			 (idlwave-is-help-topic
			  (idlwave-make-full-name class name)))))
		 word beg end doit)
	    (goto-char (point-min))
	    (re-search-forward "possible completions are:" nil t)
	    (while (re-search-forward "\\s-\\([A-Za-z0-9_]+\\)\\(\\s-\\|\\'\\)"
				      nil t)
	      (setq beg (match-beginning 1) end (match-end 1)
		    word (match-string 1) doit nil)
	      (cond
	       ((eq what 'class)
		(setq doit (idlwave-is-help-topic word)))
	       ((memq what '(procedure function routine))
		(if (eq class t)
		    (setq doit (idlwave-any-help-topic 
				(idlwave-all-method-classes
				 (idlwave-sintern-method word) type)))
		  (if sclasses
		      (setq doit (idlwave-any-help-topic
				  (mapcar (lambda (x)
					    (idlwave-make-full-name x word))
					  (idlwave-members-only
					   (idlwave-all-method-classes
					    (idlwave-sintern-method word) type)
					   (cons class sclasses)))))
		    (setq doit (idlwave-is-help-topic
				(idlwave-make-full-name class word))))))
	       ((eq what 'keyword)
		(if (eq class t)
		    (setq doit (idlwave-any-help-topic
				(idlwave-all-method-classes
				 (idlwave-sintern-method name) type)))
		  (if sclasses
		      (setq doit (idlwave-any-help-topic
				  (mapcar 
				   (lambda (x)
				     (idlwave-make-full-name x name))
				   (idlwave-members-only
				    (idlwave-all-method-keyword-classes
				     (idlwave-sintern-method name)
				     (idlwave-sintern-keyword word)
				     type)
				    (cons class sclasses)))))
		    (setq doit kwd-doit))))
	       ((and (symbolp what) ; FIXME: document this.
		     (fboundp what))
		(setq doit (funcall what 'test word))))
	      (if doit
		  (let ((buffer-read-only nil))
		    (add-text-properties beg end props)))
	      (goto-char end)))))))

;; Arrange for this function to be called after completion
(add-hook 'idlwave-completion-setup-hook
	  'idlwave-highlight-linked-completions)

(defvar idlwave-help-return-frame nil
  "The frame to return to from the help frame.")

(defun idlwave-help-quit ()
  "Exit IDLWAVE Help buffer.  Kill the dedicated frame if any."
  (interactive)
  (cond ((and idlwave-help-use-dedicated-frame
	      (eq (selected-frame) idlwave-help-frame))
	 (if (and idlwave-experimental
		  (frame-live-p idlwave-help-return-frame))
	     ;; Try to select the return frame.
	     ;; This can crash on slow network connections, obviously when
	     ;; we kill the help frame before the return-frame is selected.
	     ;; To protect the workings, we wait for up to one second 
	     ;; and check if the return-frame *is* now selected.
	     ;; This is marked "eperimental" since we are not sure when its OK.
	     (let ((maxtime 1.0) (time 0.) (step 0.1))
	       (select-frame idlwave-help-return-frame)
	       (while (and (sit-for step)
			   (not (eq (selected-frame) idlwave-help-return-frame))
			   (< (setq time (+ time step)) maxtime)))))
	 (delete-frame idlwave-help-frame))
	((window-configuration-p idlwave-help-window-configuration)
	 (set-window-configuration idlwave-help-window-configuration)
	 (select-window (previous-window)))
	(t (kill-buffer (idlwave-help-get-help-buffer)))))

(defun idlwave-help-follow-link (ev)
  "Try the word at point as a help topic.  If positive, display topic."
  (interactive "e")
  (mouse-set-point ev)
  (let* ((beg (or (previous-single-property-change (1+ (point))
						   'idlwave-help-link)
		  (point-min)))
	 (end (or (next-single-property-change (point) 'idlwave-help-link)
		  (point-max)))
	 (this-word (downcase (buffer-substring beg end)))
	 (ass (assoc this-word idlwave-help-special-topic-words))
	 (topic (if ass (or (cdr ass) (car ass)) this-word)))
    (cond ((idlwave-is-help-topic topic)
	   (idlwave-online-help
	    (idlwave-help-maybe-translate topic)))
	  ((string-match "::" this-word)
	   (let* ((l (split-string this-word "::"))
		  (class (car l))
		  (method (nth 1 l)))
	     (idlwave-online-help nil method nil class)))
	  (t
	   (error "Cannot find help for \"%s\"" this-word)))))

(defun idlwave-help-next-topic ()
  "Select next topic in the physical sequence in the Help file."
  (interactive)
  (if (stringp idlwave-help-current-topic)
      (let* ((topic (car (car (cdr (memq (assoc idlwave-help-current-topic 
						idlwave-help-topics)
					 idlwave-help-topics))))))
	(if topic
	    (idlwave-online-help topic)
	  (error "Already in last topic")))
    (error "No \"next\" topic")))

(defun idlwave-help-previous-topic ()
  "Select previous topic in the physical sequence in the Help file."
  (interactive)
  (if (stringp idlwave-help-current-topic)
      (let* ((topic (car (nth (- (length idlwave-help-topics)
				 (length (memq (assoc idlwave-help-current-topic 
						      idlwave-help-topics)
					       idlwave-help-topics))
				 1)
			      idlwave-help-topics))))
	(if topic
	    (idlwave-online-help topic)
	  (error "Already in first topic")))
    (error "No \"previous\" topic")))

(defun idlwave-help-back ()
  "Select previous topic as given by help history stack."
  (interactive)
  (if idlwave-help-stack-back
      (let* ((back idlwave-help-stack-back)
	     (fwd idlwave-help-stack-forward)
	     (goto (car back)))
	(setq back (cdr back))
	(setq fwd (cons (cons idlwave-help-current-topic (window-start)) fwd))
	(if (consp (car goto))
	    (apply 'idlwave-online-help nil (car goto))
	  (idlwave-online-help (car goto)))
	(set-window-start (selected-window) (cdr goto))
	(setq idlwave-help-stack-forward fwd
	      idlwave-help-stack-back back))
    (error "Cannot go back any further in history")))

(defun idlwave-help-forward ()
  "Select next topic as given by help history stack.
Only accessible if you have walked back with `idlwave-help-back' first."
  (interactive)
  (if idlwave-help-stack-forward
      (let* ((back idlwave-help-stack-back)
	     (fwd idlwave-help-stack-forward)
	     (goto (car fwd)))
	(setq fwd (cdr fwd))
	(setq back (cons (cons idlwave-help-current-topic (window-start)) back))
	(if (consp (car goto))
	    (apply 'idlwave-online-help nil (car goto))
	  (idlwave-online-help (car goto)))
	(set-window-start (selected-window) (cdr goto))
	(setq idlwave-help-stack-forward fwd
	      idlwave-help-stack-back back))
    (error "Cannot go forward any further in history")))

(defun idlwave-help-clear-history ()
  "Clear the history."
  (interactive)
  (setq idlwave-help-stack-back nil
	idlwave-help-stack-forward nil))

(defun idlwave-help-load-entire-file ()
  "Load the entire help file for global searches."
  (interactive)
  (let ((buffer-read-only nil))
    (idlwave-help-load-topic "***")
    (message "Entire Help file loaded")))

(defun idlwave-find-help (class1 routine1 keyword1)
  "Find help corresponding to the arguments."
  (let ((search-list (idlwave-help-make-search-list class1 routine1 keyword1))
	class routine keyword topic
	entry pre-re pos-re found kwd-re
	pos-p not-first)
    
    (when (or class1 routine1)
      (save-excursion
	(set-buffer (idlwave-help-get-help-buffer))
	;; Loop over all possible search combinations
	(while (and (not found)
		    (setq entry (car search-list)))
	  (setq search-list (cdr search-list))
	  (catch 'next
	    (setq class (nth 0 entry)
		  routine (nth 1 entry)
		  keyword (nth 2 entry))
	    
	    ;; The [XYZ] keywords need a special search strategy
	    (if (and keyword (string-match "^[xyz]" keyword))
		(setq kwd-re (format "\\(%s\\|\\[[xyz]+\\]\\)%s"
				     (substring keyword 0 1)
				     (substring keyword 1)))
	      (setq kwd-re keyword))
	    
	    ;; Determine the topic, and the regular expressions for
	    ;; narrowing and window start during display.
	    (setq topic (if class
			    (if routine (concat class "::" routine) class)
			  routine))
	    (setq pre-re nil pos-re nil found nil)
	    (setq pos-p nil)
	    (cond ((and (stringp keyword) (string-match "^!" keyword))
		   ;; A system keyword
		   (setq pos-re (concat "^[ \t]*"
					"\\(![a-zA-Z0-9_]+ *, *\\)*"
					keyword
					"\\( *, *![a-zA-Z0-9_]+ *\\)*"
					" *\\([sS]ystem +[vV]ariables?\\)?"
					"[ \t]*$")))
		  ((and class routine)
		   ;; A class method
		   (if keyword 
		       (setq pos-re (concat
				     "^ *"
				     kwd-re
				     " *\\(( *\\(get *, *set\\|get\\|set\\) *)\\)?"
				     " *$"))))
		  (routine
		   ;; A normal routine
		   (if keyword 
		       (setq pre-re "^ *keywords *$"
			     pos-re (concat
				     "^ *"
				     kwd-re
				     " *$"))))
		  (class
		   ;; Just a class
		   (if keyword 
		       (setq pre-re "^ *keywords *$"
			     pos-re (concat
				     "^ *"
				     kwd-re
				     " *\\(( *\\(get *, *set\\|get\\|set\\) *)\\)?"
				     " *$")))))
	    ;; Load the correct help topic into this buffer
	    (widen)
	    (if (not (equal topic idlwave-help-current-topic))
		;; The last topic was different - load the new one.
		(let ((buffer-read-only nil))
		  (or (idlwave-help-load-topic topic)
		      (throw 'next nil))))
	    (goto-char (point-min))
	    
	    ;; Position cursor and window start.
	    (if pre-re
		(re-search-forward pre-re nil t))
	    (if (and pos-re
		     (setq pos-p (re-search-forward pos-re nil t)))
		(progn (goto-char (match-beginning 0))))
	    ;; Determine if we found what we wanted
	    (setq found (if pos-re
			    pos-p
			  (not not-first)))
	    (setq not-first t)))
	(if found
	    (point)
	  (or idlwave-help-use-dedicated-frame
	      (idlwave-help-quit))
	  nil)))))

(defvar default-toolbar-visible-p)
(defvar idlwave-help-activate-links-aggressively)
(defvar idlwave-min-frame-width nil)
(defun idlwave-help-display-help-window (pos &optional nolinks)
  "Display the help window and move window start to POS.
See `idlwave-help-use-dedicated-frame'."
  (let ((cw (selected-window))
	(buf (idlwave-help-get-help-buffer))
	(frame-params (copy-sequence idlwave-help-frame-parameters))
	(min-width idlwave-min-frame-width))
    (when (integerp min-width)
      (let ((cur-width (assq 'width frame-params)))
	(if cur-width
	    (setcdr cur-width min-width)
	  (setq frame-params (cons (cons 'width min-width) frame-params))))
      (setq idlwave-min-frame-width nil))
    (if (and window-system idlwave-help-use-dedicated-frame)
	(progn
	  ;; Use a special frame for this
	  (if (frame-live-p idlwave-help-frame)
	      ;; Possibly widen the help window
	      (if (and (integerp min-width)
		       (< (frame-width idlwave-help-frame) 
			  min-width))
		  (set-frame-width idlwave-help-frame min-width))
	    (setq idlwave-help-frame
		  (make-frame frame-params))
	    ;; Strip menubar (?) and toolbar from the Help frame.
	    (if (fboundp 'set-specifier)
		(progn
		  ;; XEmacs
		  (let ((sval (cons idlwave-help-frame nil)))
		    ;; (set-specifier menubar-visible-p sval)
		    (set-specifier default-toolbar-visible-p sval)))
	      ;; Emacs
	      (modify-frame-parameters idlwave-help-frame
				       '(;;(menu-bar-lines . 0)
					 (tool-bar-lines . 0)))))
	  ;; We should use display-buffer here, but there are problems on Emacs
	  (select-frame idlwave-help-frame)
	  (switch-to-buffer buf))
      ;; Do it in this frame and save the window configuration
      (if (not (get-buffer-window buf nil))
	  (setq idlwave-help-window-configuration 
		(current-window-configuration)))
      (display-buffer buf nil (selected-frame))
      (select-window (get-buffer-window buf)))
    (raise-frame)
    (goto-char pos)
    (recenter 0)
    (if nolinks
	nil
      (idlwave-help-activate-see-also)
      (idlwave-help-activate-methods)
      (idlwave-help-activate-class)
      (if idlwave-help-activate-links-aggressively
	  (idlwave-help-activate-aggressively)))
    (select-window cw)))

(defun idlwave-help-select-help-frame ()
  "Select the help frame."
  (if (and (frame-live-p idlwave-help-frame)
	   (not (eq (selected-frame) idlwave-help-frame)))
      (progn
	(setq idlwave-help-return-frame (selected-frame))
	(select-frame idlwave-help-frame))))

(defun idlwave-help-return-to-calling-frame ()
  "Select the frame from which the help frame was selected."
  (interactive)
  (if (and (frame-live-p idlwave-help-return-frame)
	   (not (eq (selected-frame) idlwave-help-return-frame)))
      (select-frame idlwave-help-return-frame)))

(defvar idlwave-help-is-source)
(defun idlwave-help-load-topic (topic)
  "Load topic TOPIC into the current buffer."
  (setq idlwave-help-is-source nil)
  (let* ((entry (assoc topic idlwave-help-topics))
	 beg end)
    (if (equal topic "***")
	;; Make it load the whole file
	(setq entry (cons t nil)))
    (if entry
	(progn
	  (setq beg (cdr entry)
		end (cdr (car (cdr (memq entry idlwave-help-topics)))))
	  (erase-buffer)
	  (setq idlwave-help-current-topic topic)
	  (setq idlwave-help-mode-line-indicator (upcase topic))
	  (insert-file-contents idlwave-help-file nil beg end)
	  (set-buffer-modified-p nil)
	  t)
      nil)))

(defvar idlwave-extra-help-function)
(defun idlwave-online-help (topic &optional name type class keyword)
  "Display help on a certain topic.
Note that the topics are the section headings in the IDL documentation.
Thus the right topic may not always be easy to guess."
  (interactive (list (completing-read "Topic: " idlwave-help-topics)))
  (let ((last-topic idlwave-help-current-topic)
	(last-ws (window-start (get-buffer-window "*IDLWAVE Help*" t))))
    ;; Push the current topic on the history stack
    (if last-topic
	(progn
	  (if (equal last-topic (car (car idlwave-help-stack-back)))
	      (setcdr (car idlwave-help-stack-back) (or last-ws 1))
	    (setq idlwave-help-stack-back
		  (cons (cons last-topic (or last-ws 1))
			idlwave-help-stack-back)))))
    (if (> (length idlwave-help-stack-back) 20)
	(setcdr (nthcdr 17 idlwave-help-stack-back) nil))
    (setq idlwave-help-stack-forward nil)
    (if topic
	;; A specific topic
	(progn
	  (save-excursion
	    (set-buffer (idlwave-help-get-help-buffer))
	    (let ((buffer-read-only nil))
	      (idlwave-help-load-topic (downcase topic))))
	  (idlwave-help-display-help-window 0))
      ;; Find the right topic and place
      (if idlwave-extra-help-function
	  (condition-case nil
	      (idlwave-routine-info-help name type class keyword)
	    (error
	     (idlwave-help-get-special-help name type class keyword)))
	(idlwave-routine-info-help name type class keyword)))))

(defun idlwave-routine-info-help (routine type class &optional keyword)
  "Show help about KEYWORD of ROUTINE in CLASS.  TYPE is currently ignored.
When CLASS is nil, look for a normal routine.
When ROUTINE is nil, display the info about the entire class.
When KEYWORD is non-nil, position window start at the description of that
keyword, but still have the whole topic in the buffer."
  (let ((cw (selected-window))
	(help-pos (idlwave-find-help class routine keyword)))
    (if help-pos
	(idlwave-help-display-help-window help-pos)
      (idlwave-help-error routine type class keyword))
    (select-window cw)))

(defun idlwave-help-get-special-help (name type class keyword)
  "Call the function given by `idlwave-extra-help-function'."
  (let* ((cw (selected-window))
	 (help-pos (save-excursion
		     (set-buffer (idlwave-help-get-help-buffer))
		     (let ((buffer-read-only nil))
		       (funcall idlwave-extra-help-function 
				name type class keyword)))))
    (if help-pos
	(progn
	  (setq idlwave-help-current-topic (list name type class keyword))
	  (idlwave-help-display-help-window help-pos 'no-links))
      (setq idlwave-help-current-topic nil)
      (idlwave-help-error name type class keyword))
    (select-window cw)))

;; A special "extra" help routine for source-level help in files.
(defvar idlwave-help-def-pos)
(defvar idlwave-help-args)
(defvar idlwave-help-in-header)
(defvar idlwave-help-is-source)
(defvar idlwave-help-fontify-source-code)
(defvar idlwave-help-source-try-header)
(defun idlwave-help-with-source (name type class keyword)
  "Provide help for routines not documented in the IDL manual.  Works
by loading the routine source file into the help buffer.  Depending on
the value of `idlwave-help-source-try-header', it shows the routine
definition or the header description.  If
`idlwave-help-class-struct-tag' is non-nil, keyword is a tag to show
help on from the class definition structure.  If
`idlwave-help-struct-tag' is non-nil, show help from the matching
structure tag definition.

This function can be used as `idlwave-extra-help-function'."
  (let* ((class-struct-tag idlwave-help-do-class-struct-tag)
	 (struct-tag idlwave-help-do-struct-tag)
	 (case-fold-search t)
	 file header-pos def-pos in-buf)
    (if (not struct-tag) 
	(setq file
	      (idlwave-expand-lib-file-name
	       (cdr (nth 3 (idlwave-best-rinfo-assoc
			    name (or type t) class (idlwave-routines)))))))
    (setq idlwave-help-def-pos nil
	  idlwave-help-args (list name type class keyword)
	  idlwave-help-in-header nil
	  idlwave-help-is-source t
	  idlwave-help-do-struct-tag nil
	  idlwave-help-do-class-struct-tag nil)
    (if (or struct-tag (stringp file))
	(progn
	  (setq in-buf ; structure-tag completion is always in current buffer
		(if struct-tag 
		    idlwave-current-tags-buffer
		  (idlwave-get-buffer-visiting file)))
	  ;; see if file is in a visited buffer, insert those contents
	  (if in-buf
	      (progn
		(setq file (buffer-file-name in-buf))
		(erase-buffer)
		(insert-buffer in-buf))
	    (if (file-exists-p file) ;; otherwise just load the file
		(progn
		  (erase-buffer)
		  (insert-file-contents file nil nil nil 'replace))
	      (idlwave-help-error name type class keyword)))
	  (if (and idlwave-help-fontify-source-code (not in-buf))
	      (idlwave-help-fontify)))
      (idlwave-help-error name type class keyword))
    (setq idlwave-help-mode-line-indicator file)

    ;; Try to find a good place to display
    (setq def-pos
	  ;; Find the class structure tag if that's what we're after
	  (cond 
	   ;; Class structure tags: find the class definition
	   (class-struct-tag
	    (save-excursion 
	      (setq class
		    (if (string-match "[a-zA-Z0-9]\\(__\\)" name) 
			(substring name 0 (match-beginning 1))
		      idlwave-current-tags-class))
	      (and
	       (idlwave-find-class-definition class)
	       (idlwave-find-struct-tag keyword))))
	   
	   ;; Generic structure tags: the structure definition
	   ;; location within the file has been recorded in
	   ;; `struct-tag'
	   (struct-tag
	    (save-excursion
	      (and
	       (integerp struct-tag)
	       (goto-char struct-tag)
	       (idlwave-find-struct-tag keyword))))
	   
	   ;; Just find the routine definition
	   (t
	    (idlwave-help-find-routine-definition name type class keyword)))
	  idlwave-help-def-pos def-pos)

    (if (and idlwave-help-source-try-header 
	     (not (or struct-tag class-struct-tag)))
	;; Check if we can find the header
	(save-excursion
	  (goto-char (or def-pos (point-max)))
	  (setq header-pos (idlwave-help-find-in-doc-header
			    name type class keyword 'exact)
		idlwave-help-in-header header-pos)))

    (if (or header-pos def-pos)
	(progn 
	  (if (boundp 'idlwave-min-frame-width)
	      (setq idlwave-min-frame-width 80))
	  (goto-char (or header-pos def-pos)))
      (idlwave-help-error name type class keyword))
    
    (point)))


;; FIXME: Should use type here.
(defun idlwave-help-find-routine-definition (name type class keyword)
  "Find the definition of routine CLASS::NAME in current buffer.
TYPE and KEYWORD are ignored.
Returns hte point of match if successful, nil otherwise."
  (save-excursion
    (goto-char (point-max))
    (if (re-search-backward 
	 (concat "^[ \t]*\\(pro\\|function\\)[ \t]+"
		 (regexp-quote (downcase (idlwave-make-full-name class name)))
		 "[, \t\r\n]")
	 nil t)
	(match-beginning 0)
      nil)))

(defvar idlwave-doclib-start)
(defvar idlwave-doclib-end)

(defun idlwave-help-find-in-doc-header (name type class keyword
					     &optional exact)
  "Find the requested help in the doc-header above point.
First checks if there is a doc-lib header which describes the correct routine.
Then tries to find the KEYWORDS section and the KEYWORD, if given.
Returns the point which should be window start of the help window.
If EXACT is non-nil, the full help position must be found - down to the
keyword requested.  This setting is for context help, if the exact
spot is needed.
If EXACT is nil, the position of the header is returned if it
describes the correct routine - even if the keyword description cannot
be found.
TYPE is ignored.

This function expects a more or less standard routine header.  In
particlar it looks for the `NAME:' tag, either with a colon, or alone
on a line.  Then `NAME:' must be followed by the routine name on the
same or the next line.  
When KEYWORD is non-nil, looks first for a `KEYWORDS' section.  It is
amazing how inconsisten this is through some IDL libraries I have
seen.  We settle for a line containing an upper case \"KEYWORD\"
string.  If this line is not fould we search for the keyword anyway to
increase the hit-rate

When one of these sections exists we check for a line starting with any of

  /KEYWORD  KEYWORD-  KEYWORD=  KEYWORD

with spaces allowed between the keyword and the following dash or equal sign.
If there is a match, we assume it is the keyword description."
  (let* ((case-fold-search t)
	 ;; NAME tag plus the routine name.  The new version is from JD.
	 (name-re (concat 
		   "\\(^;+\\*?[ \t]*name\\([ \t]*:\\|[ \t]*$\\)[ \t]*\\(\n;+[ \t]*\\)*"
		   (if (stringp class)
		       (concat "\\(" (regexp-quote (downcase class))
			       "::\\)?")
		     "")
		   (regexp-quote (downcase name))
		   "\\>\\)"
		   "\\|"
		   "\\(^;+[ \t]*"
		   (regexp-quote (downcase name))
		   ":[ \t]*$\\)"))
;	 (name-re (concat 
;		   "\\(^;+\\*?[ \t]*name\\([ \t]*:\\|[ \t]*$\\)[ \t]*\\(\n;+[ \t]*\\)?"
;		   (if (stringp class)
;		       (concat "\\(" (regexp-quote (downcase class))
;			       "::\\)?")
;		     "")
;		   (regexp-quote (downcase name))
;		   "\\>"))
	 ;; Header start plus name
	 (header-re (concat "\\(" idlwave-doclib-start "\\).*\n"
			    "\\(^;+.*\n\\)*"
			    "\\(" name-re "\\)"))
	 ;; A keywords section
	 (kwds-re "^;+[ \t]+KEYWORD PARAMETERS:[ \t]*$")    ; hard
	 (kwds-re2 (concat		                    ; forgiving
		    "^;+\\*?[ \t]*"
		    "\\([-A-Z_ ]*KEYWORD[-A-Z_ ]*\\)"
		    "\\(:\\|[ \t]*\n\\)"))
	 ;; The keyword description line.
	 (kwd-re (if keyword                                ; hard (well...)
		     (concat
		      "^;+[ \t]+"
		      "\\(/" (regexp-quote (upcase keyword))
		      "\\|"  (regexp-quote (upcase keyword)) "[ \t]*[-=:\n]"
		      "\\)")))
	 (kwd-re2 (if keyword                               ; forgiving
		      (concat
		       "^;+[ \t]+"
		       (regexp-quote (upcase keyword))
		      "\\>")))
	 dstart dend name-pos kwds-pos kwd-pos)
    (catch 'exit 
      (save-excursion
	(goto-char (point-min))
	(while (and (setq dstart (re-search-forward idlwave-doclib-start nil t))
		    (setq dend (re-search-forward idlwave-doclib-end nil t)))
	  ;; found a routine header
	  (goto-char dstart)
	  (if (setq name-pos (re-search-forward name-re dend t))
	      (progn 
		(if keyword
		    ;; We do need a keyword
		    (progn
		      ;; Try to find a keyword section, but don't force it.
		      (goto-char name-pos)
		      (if (let ((case-fold-search nil))
			    (or (re-search-forward kwds-re dend t)
				(re-search-forward kwds-re2 dend t)))
			  (setq kwds-pos (match-beginning 0)))
		      ;; Find the keyword description
		      (if (or (let ((case-fold-search nil))
				(re-search-forward kwd-re dend t))
			      (re-search-forward kwd-re dend t)
			      (let ((case-fold-search nil))
				(re-search-forward kwd-re2 dend t))
			      (re-search-forward kwd-re2 dend t))
			  (setq kwd-pos (match-beginning 0))
			(if exact
			    (progn
			      (idlwave-help-diagnostics
			       (format "Could not find description of kwd %s"
				       (upcase keyword)))
			      (throw 'exit nil))))))
		;; Return the best position we got
		(throw 'exit (or kwd-pos kwds-pos name-pos dstart)))
	    (goto-char dend))))
      (idlwave-help-diagnostics "Could not find doclib header")
      (throw 'exit nil))))

(defun idlwave-help-diagnostics (string &optional ding)
  "Add a diagnostics string to the list.
When DING is non-nil, ring the bell as well."
  (if (boundp 'idlwave-help-diagnostics)
      (progn
	(setq idlwave-help-diagnostics
	      (cons string idlwave-help-diagnostics))
	(if ding (ding)))))

(defun idlwave-help-toggle-header-top-and-def (arg)
  (interactive "P")
  (if (not idlwave-help-is-source)
      (error "This is not a source file"))
  (let (pos)
    (if idlwave-help-in-header
	;; Header was the last thing displayed
	(progn
	  (setq idlwave-help-in-header nil)
	  (setq pos idlwave-help-def-pos))
      ;; Try to display header
      (setq pos (idlwave-help-find-in-doc-header
		 (nth 0 idlwave-help-args)
		 (nth 1 idlwave-help-args)
		 (nth 2 idlwave-help-args)
		 nil))
      (if pos
	  (setq idlwave-help-in-header t)
	(error "Cannot find doclib header for routine %s"
	       (idlwave-make-full-name (nth 2 idlwave-help-args)
				       (nth 0 idlwave-help-args)))))
    (if pos
	(progn
	  (goto-char pos)
	  (recenter 0)))))

(defun idlwave-help-find-first-header (arg)
  (interactive "P")
  (let (pos)
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward idlwave-doclib-start nil t)
	  (setq pos (match-beginning 0))))
    (if pos
	(progn
	  (goto-char pos)
	  (recenter 0))
      (error "No DocLib Header in current file"))))

(defun idlwave-help-find-header (arg)
  "Jump to the DocLib Header."
  (interactive "P")
  (if arg
      (idlwave-help-find-first-header nil)
    (setq idlwave-help-in-header nil)
    (idlwave-help-toggle-header-match-and-def arg 'top)))
  
(defun idlwave-help-toggle-header-match-and-def (arg &optional top)
  (interactive "P")
  (if (not idlwave-help-is-source)
      (error "This is not a source file"))
  (let ((args idlwave-help-args)
	pos)
    (if idlwave-help-in-header
	;; Header was the last thing displayed
	(progn
	  (setq idlwave-help-in-header nil)
	  (setq pos idlwave-help-def-pos))
      ;; Try to display header
      (setq pos (apply 'idlwave-help-find-in-doc-header
		       (if top 
			   (list (car args) (nth 1 args) (nth 2 args) nil)
			 args)))
      (if pos
	  (setq idlwave-help-in-header t)
	(error "Cannot find doclib header for routine %s"
	       (idlwave-make-full-name (nth 2 idlwave-help-args)
				       (nth 0 idlwave-help-args)))))
    (if pos
	(progn
	  (goto-char pos)
	  (recenter 0)))))

(defvar font-lock-verbose)
(defvar idlwave-mode-syntax-table)
(defvar idlwave-font-lock-defaults)
(defun idlwave-help-fontify ()
  "Fontify the Help buffer as source code.
Useful when source code is displayed as help.  See the option
`idlwave-help-fontify-source-code'."
  (interactive)
  (if (not idlwave-help-is-source)
      (error "Fontification only for source files...")
    (if (and (featurep 'font-lock)
	     idlwave-help-is-source)
	(let ((major-mode 'idlwave-mode)
	      (font-lock-verbose
	       (if (interactive-p) font-lock-verbose nil))
	      (syntax-table (syntax-table)))
	  (unwind-protect
	      (progn
		(set-syntax-table idlwave-mode-syntax-table)
		(set (make-local-variable 'font-lock-defaults)
		     idlwave-font-lock-defaults)
		(font-lock-fontify-buffer))
	    (set-syntax-table syntax-table))))))

(defun idlwave-help-error (name type class keyword)
  (error "Cannot find help on %s%s"
	 (idlwave-make-full-name class name)
	 (if keyword (format ", keyword %s" (upcase keyword)) "")))

(defun idlwave-help-get-help-buffer ()
  "Return the IDLWAVE Help buffer.  Make it first if necessary."
  (let ((buf (get-buffer "*IDLWAVE Help*")))
    (if buf
	nil
      (setq buf (get-buffer-create "*IDLWAVE Help*"))
      (save-excursion
	(set-buffer buf)
	(idlwave-help-mode)))
    buf))

(defun idlwave-help-make-search-list (class routine keyword)
  "Return a list of all possible search compinations.
For some routines, keywords are described under a different topic or routine.
This function returns a list of entries (class routine keyword) to be
searched.  It also makes everything downcase, to make sure the regexp
searches will work properly with `case-fold-search'"
  (let (routines list)
    (setq routine (idlwave-downcase-safe routine)
	  class (idlwave-downcase-safe class)
	  keyword (idlwave-downcase-safe keyword))
    (setq routine (or (cdr (assoc routine idlwave-help-name-translations))
		      routine))
    (setq routines (append (cdr (assoc routine idlwave-help-alt-names))
			   (list routine)))
    (if (equal routine "obj_new")
	(setq routines (cons (list (idlwave-downcase-safe
				    idlwave-current-obj_new-class)
				   "init" keyword)
			      routines)))
    (while routines
      (if (consp (car routines))
	  (setq list (cons (car routines) list))
	(setq list (cons (list class (car routines) keyword) list)))
      (setq routines (cdr routines)))
    list))

(defvar idlwave-help-link-map (copy-keymap idlwave-help-mode-map)
  "The keymap for activated stuff in the Help application.")

(define-key idlwave-help-link-map (if (featurep 'xemacs) [button1] [mouse-1])
  'idlwave-help-follow-link)
(define-key idlwave-help-link-map (if (featurep 'xemacs) [button2] [mouse-2])
  'idlwave-help-follow-link)
(define-key idlwave-help-link-map (if (featurep 'xemacs) [button3] [mouse-3])
  'idlwave-help-follow-link)

(defun idlwave-help-activate-see-also ()
  "Highlight the items under `See Also' in indicate they may be used as links."
  (save-excursion
    (if (re-search-forward "^ *See Also *$" nil t)
	(let ((lim (+ (point) 500))
	      (case-fold-search nil)
	      (props (list 'face 'idlwave-help-link-face
			   'idlwave-help-link t
			   (if (featurep 'xemacs) 'keymap 'local-map)
			   idlwave-help-link-map
			   'mouse-face 'highlight))
	      (buffer-read-only nil))
	  (while (re-search-forward "\\(\\.?[A-Z][A-Z0-9_]+\\)" lim t)
	    (if (idlwave-is-help-topic (match-string 1))
		(add-text-properties (match-beginning 1) (match-end 1) props)))))))

(defun idlwave-help-activate-methods ()
  "Highlight the items under `See Also' in indicate they may be used as links."
  (save-excursion
    (if (re-search-forward "^ *Methods *$" nil t)
	(let ((lim (+ (point) 1000))
	      (case-fold-search t)
	      (props (list 'face 'idlwave-help-link-face
			   'idlwave-help-link t
			   (if (featurep 'xemacs) 'keymap 'local-map)
			   idlwave-help-link-map
			   'mouse-face 'highlight))
	      (buffer-read-only nil))
	  (while (re-search-forward 
		  "^ *\\* +\"?\\([A-Z][A-Z0-9_]+::[A-Z][A-Z0-9_]+\\)\"?\\( *on +page +[0-9]*\\)? *" lim t)
	    (add-text-properties (match-beginning 1) (match-end 1) props))))))

(defun idlwave-help-activate-class ()
  "Highlight the items under `See Also' in indicate they may be used as links."
  (save-excursion
    (goto-char (point-min))
    (if (looking-at "\\([A-Z][A-Z0-9_]+\\)::[A-Z][A-Z0-9_]+ *$")
	(let ((props (list 'face 'idlwave-help-link-face
			   'idlwave-help-link t
			   (if (featurep 'xemacs) 'keymap 'local-map)
			   idlwave-help-link-map
			   'mouse-face 'highlight))
	      (buffer-read-only nil))
	  (add-text-properties (match-beginning 1) (match-end 1) props)))))

(defun idlwave-help-activate-aggressively ()
  (interactive)
  (let ((props (list 'face 'idlwave-help-link-face
		     'idlwave-help-link t
		     (if (featurep 'xemacs) 'keymap 'local-map)
		     idlwave-help-link-map
		     'mouse-face 'highlight))
	(except
	 '("For" "If" "Example" "Wait" "Do" "Events" "Fonts" "Device"
	   "Reference" "Guide" "Routines" "Return" "Print" "Reverse"
	   "Function" "Pro" "Where" "Plot"))
	(case-fold-search nil)
	(buffer-read-only nil)
	b e s bc ac)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\.?[A-Z][a-zA-Z0-9_:]+" nil t)
	(setq b (match-beginning 0) e (match-end 0) s (match-string 0)
	      bc (char-before b) ac (char-after e))
	(if (and (idlwave-is-help-topic s)
		 (not (member s except))
		 (not (eq bc ?/)) (not (eq ac ?=))
		 (string-match "[A-Z]" (substring s 1)) ; 2nd UPPER char
		 (not (equal (downcase s) idlwave-help-current-topic)))
	    (add-text-properties b e props)))
      (goto-char (point-min))
      (while (re-search-forward "\"" nil t)
	(when (looking-at "\\([^\"]+\\)\"")
	  (setq b (match-beginning 1) e (match-end 1) s (match-string 1))
	  (when (< (length s) 100)
	    (while (string-match "\\s-\\s-+" s)
	      (setq s (replace-match " " t t s)))
	  (if (idlwave-is-help-topic s)
	      (add-text-properties b e props))))))))

(defun idlwave-grep (regexp list)
  (let (rtn)
    (while list
      (if (string-match regexp (car list))
	  (setq rtn (cons (car list) rtn)))
      (setq list (cdr list)))
    (nreverse rtn)))

(defun idlwave-is-help-topic (word)
  "Try if this could be a help topic.
Also checks special translation lists."
  (setq word (downcase word))
  (car
   (or (assoc word idlwave-help-topics)
       (assoc word idlwave-help-name-translations)
       (assoc word idlwave-help-special-topic-words))))

(defun idlwave-help-maybe-translate (word)
  "Return the real topic assiciated with WORD."
  (setq word (downcase word))
  (or (car (assoc word idlwave-help-topics))
      (cdr (assoc word idlwave-help-name-translations))
      (cdr (assoc word idlwave-help-special-topic-words))))

(defun idlwave-grep-help-topics (list)
  "Return only the classis in LIST which are also help topics."
  (delq nil (mapcar 'idlwave-is-help-topic list)))

(defun idlwave-any-help-topic (list)
  "Return the first member in LIST which is also a help topic."
  (catch 'exit
    (while list
      (if (idlwave-is-help-topic (car list))
	  (throw 'exit (car list))
	(setq list (cdr list))))))

;;; INSERT-HELP-TOPICS-HERE
;;; idlw-help.el ends here
