;;; org-task-scheduler.el --- The Org Task Scheduler -*- lexical-binding: t -*-

;; Author: Jason Tian <hi@jsntn.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: gtd
;; URL: https://github.com/jsntn/org-task-scheduler.el

;;; Commentary:
;;; Code:


(defvar org-task-scheduler/buffer "*Alerts*"
  "Name of the buffer to display the alert entries.")

(defvar org-task-scheduler/enable-links nil
  "Whether to make task entries clickable links to their source.
When nil (default), tasks are displayed as plain text.
When t, tasks become clickable links that jump to the source location.")

(defvar org-task-scheduler/minutes-to-schedule-time 30
  "Time to schedule time in minutes (default: 30 minutes).

This variable determines how many minutes in advance of a task's
scheduled time. When a task's schedule falls within this time
range, the scheduler can help you with special handling or
notifications for upcoming tasks, allowing you to prepare for the
task.")

(defvar org-task-scheduler/minutes-to-deadline-cutoff 600
  "Time to deadline cutoff in minutes (default: 600 minutes).

This variable determines how many minutes in advance of a task's
deadline cutoff. When a task's deadline is within this time
frame, it will be considered as approaching the cutoff
point. This allows for special handling or notifications for
tasks approaching their deadlines.")

(defvar org-task-scheduler/minutes-past-schedule-time 600
  "Time past schedule time in minutes (default: 600 minutes).

This variable determines the allowable time window, in minutes,
after a task's scheduled time, during which the task is still
considered relevant for handling. Tasks falling within this
window are not considered overdue, allowing for flexibility in
task management, for special handling, notifications, and etc.")

(defvar org-task-scheduler/minutes-past-deadline-cutoff 600
  "Time past deadline cutoff in minutes (default: 600 minutes).

This variable determines the time window, in minutes, beyond the
deadline cutoff, during which the task can still be considered
for handling. Tasks falling within this window are not considered
overdue, allowing for flexibility in task management, for special
handling, notifications, and etc.")

(defvar org-task-scheduler/default-schedule-time "10:00"
  "Default time for the tasks when no explicit time is specified in
SCHEDULE (default: 10:00).")

(defvar org-task-scheduler/default-deadline-time "16:00"
  "Default time for the tasks when no explicit time is specified in
DEADLINE (default: 16:00).")

(defvar org-task-scheduler/inherit-tags t
  "Inherit tags or not (default: t).")

(defvar org-task-scheduler/included-tags '()
  "Define the list of tags used to identify tasks to scan.

If the value is empty or nil, all tasks will be included.")

(defvar org-task-scheduler/exclued-tags '("habit" "drill")
  "Define the list of tags used to exclude tasks to scan.

If the value is empty or nil, no tasks will be excluded.")

(defvar org-task-scheduler/included-todo-keywords '()
  "List of TODO keywords that should be excluded from scanning.

If the value is empty or nil, all TODO keywords will be included.")

(defvar org-task-scheduler/excluded-todo-keywords '("DONE")
  "List of TODO keywords that should be excluded from scanning.

If the value is empty or nil, no TODO keywords will be excluded.")

(defvar org-task-scheduler/included-files '()
  "Define the list of files to include in the agenda.")

(defvar org-task-scheduler/excluded-files '()
  "Define the list of files to exclude from the agenda.")

(defvar org-task-scheduler/included-entry-properties '()
  "List of entry properties that should be included from scanning.

If the value is empty or nil, all entry properties will be included.")

(defvar org-task-scheduler/excluded-entry-properties '(("STYLE" . "habit"))
  "List of entry properties that should be excluded from scanning.

If the value is empty or nil, no entry properties will be excluded.")


(defun org-task-scheduler/reminder-action ()
  "Remind me of the tasks in org-task-scheduler/buffer through
org-task-scheduler/check-tasks function."
  ;; (w32-shell-execute "open" "v:/06ac7fa7d842b75be23726222d9c0217.jpg")
  )

(defun org-task-scheduler/filtered-agenda-files ()
  "Return a filtered list of agenda files based on inclusion and exclusion criteria.

This function iterates through the list of agenda
files (org-agenda-files) and constructs a filtered list by
considering the inclusion and exclusion criteria specified in the
variables org-task-scheduler/included-files and
org-task-scheduler/excluded-files. Files are included if they
match any of the included file names and are excluded if they
match any of the excluded file names.

If org-task-scheduler/included-files is empty or nil, all files are considered
for inclusion. If org-task-scheduler/excluded-files is empty or nil, no files
are excluded.

Returns:
- A list of filtered agenda files.
"
  (let ((filtered-files nil))
    (dolist (file org-agenda-files)
      (let ((filename (file-name-nondirectory file)))
        (unless (or (member filename org-task-scheduler/excluded-files)
                    (and (not (member filename org-task-scheduler/included-files))
                         (not (null org-task-scheduler/included-files))))
          (push file filtered-files))))
    (nreverse filtered-files))) ; reverse the list to maintain order

(defun org-task-scheduler/remove-repeater-string-from-time (time-str)
  "Remove repeater string from org-mode time string.

Regarding repeater string format,
https://orgmode.org/manual/Repeated-tasks.html
"
  (if time-str
      (replace-regexp-in-string " [+.]?[+-][1-9][0-9]*[ymwdh]" "" time-str)
    nil))

(defun org-task-scheduler/set-default-time-if-no-time
    (schedule-deadline-value default-time)
  "Set default time if no time is specified in SCHEDULE or
DEADLINE."
  (if schedule-deadline-value
      (if (string-match-p
	   "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Za-z]\\{3\\} [0-9]\\{2\\}:[0-9]\\{2\\}"
	   schedule-deadline-value)
	  schedule-deadline-value
	(replace-regexp-in-string ">" (concat " " default-time ">") schedule-deadline-value))
    nil))

(defun org-task-scheduler/scan-tasks ()
  "Scan all agenda files for TODO entries with specific tags to
include and exclude, and store the task data in
org-task-scheduler/tasks."
  (interactive)
  (setq org-task-scheduler/tasks '()) ; clear existing data
  (let ((agenda-files (org-task-scheduler/filtered-agenda-files))
        (included-tags org-task-scheduler/included-tags)
        (exclued-tags org-task-scheduler/exclued-tags)
	(included-todo-keywords org-task-scheduler/included-todo-keywords)
	(excluded-todo-keywords org-task-scheduler/excluded-todo-keywords)
        (excluded-entry-properties org-task-scheduler/excluded-entry-properties)
        (included-entry-properties org-task-scheduler/included-entry-properties))
    (make-thread
     (lambda ()
       (dolist (file agenda-files)
	 (when (file-exists-p file) ; in case of non-existent agenda file...
	   (with-current-buffer (find-file-noselect file)
	     (org-map-entries
	      (lambda ()
		(let ((entry-tags (org-get-tags nil
						;; see org-get-tags for the reason to the `not ...` below,
						(not org-task-scheduler/inherit-tags)))
		      (todo-keyword (org-get-todo-state)))
		  (when (or (null included-tags) ; include all entries when included-tags is empty
			    (cl-loop for tag in included-tags
				     thereis (member tag entry-tags)))
		    (when (or (null exclued-tags) ; exclude nothing when exclued-tags is empty
			      (not (cl-loop for tag in exclued-tags
					    thereis (member tag entry-tags))))
		      ;; check if the TODO keyword is included
		      (when (or (null included-todo-keywords)
				(member todo-keyword included-todo-keywords))
			;; check if the TODO keyword is excluded
			(when (or (null excluded-todo-keywords)
				  (not (member todo-keyword excluded-todo-keywords)))
			  ;; check if any of the excluded entry properties match
			  (when (or (null excluded-entry-properties)
				    (not (cl-loop for (property . value) in excluded-entry-properties
						  thereis (and (string= (org-entry-get nil property) value)))))
			    ;; check if any of the included entry properties match
			    (when (or (null included-entry-properties)
				      (cl-loop for (property . value) in included-entry-properties
					       thereis (and (string= (org-entry-get nil property) value))))
			      (let ((task-name (org-get-heading t))
				    (schedule-date
				     (org-task-scheduler/set-default-time-if-no-time
				      (org-task-scheduler/remove-repeater-string-from-time
				       (org-entry-get nil "SCHEDULED"))
				      org-task-scheduler/default-schedule-time))
				    (deadline-date
				     (org-task-scheduler/set-default-time-if-no-time
				      (org-task-scheduler/remove-repeater-string-from-time
				       (org-entry-get nil "DEADLINE"))
				      org-task-scheduler/default-deadline-time))
				    (file-path (buffer-file-name))
				    (marker (point-marker)))
				(push (list :task-name task-name
					    :schedule-date schedule-date
					    :deadline-date deadline-date
					    :file file-path
					    :marker marker)
				      org-task-scheduler/tasks)))))))))
		nil 'file)))))
       "org-task-scheduler-scan-thread"))))

(defun org-task-scheduler/sort-lines ()
  "Sorts the lines in the org-task-scheduler/buffer BUFFER
alphabetically."
  (with-current-buffer org-task-scheduler/buffer
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let ((case-fold-search nil))
          (sort-lines nil (point-min) (point-max)))))))

(defun org-task-scheduler/m2h-format (minutes)
  "Construct the format structure as,
x.y

Where,
- the length of x = the length of INTEGER result from MINUTE to HOUR
- the length of y = 1

This will result in tasks of the same type having a consistent time
format, and this uniform content alignment improves readability. for
example,

606 minutes will be - 10.1 hours
600 minutes will be - 10.0 hours
300 minutes will be -  5.0 hours

Usage:
(org-task-scheduler/m2h-format 310)"
  (concat "%"
	  (number-to-string
	   (+ 2
	      (length
	       (number-to-string
		(/ minutes 60)))))
	  ".1f"))

(defun org-task-scheduler/escape-link-text (text)
  "Escape special characters in TEXT for safe inclusion inside Org links.
Escapes the following:
  - `[` and `]` to prevent bracket confusion
  - `|` to prevent link target/description splitting
  - `\\` to preserve literal backslashes"
  (let ((escaped text))
    ;; Escape backslash first
    (setq escaped (replace-regexp-in-string "\\\\" "\\\\\\\\" escaped))
    ;; Escape [ and ]
    (setq escaped (replace-regexp-in-string "[][]" "\\\\\\&" escaped))
    ;; Escape |
    (setq escaped (replace-regexp-in-string "|" "\\\\|" escaped))
    escaped))

(defun org-task-scheduler/escape-link-text (text)
  "Escape special characters in TEXT for safe inclusion inside Org links.
Escapes the following:
  - `[` and `]` to prevent bracket confusion
  - `|` to prevent link target/description splitting
  - `\\` to preserve literal backslashes"
  (let ((escaped text))
    ;; Escape backslash first
    (setq escaped (replace-regexp-in-string "\\\\" "\\\\\\\\" escaped))
    ;; Escape [ and ]
    (setq escaped (replace-regexp-in-string "[][]" "\\\\\\&" escaped))
    ;; Escape |
    (setq escaped (replace-regexp-in-string "|" "\\\\|" escaped))
    escaped))

(defun org-task-scheduler/insert-task-entry (prefix time-str task)
  "Insert a task entry as a literal Org link.
PREFIX is the category string (e.g., 'Missed Deadline by').
TIME-STR is the formatted time string.
TASK is the task plist containing task information.

The link target is escaped, but the display text remains unchanged."
  (let* ((task-name (plist-get task :task-name))
         (file (plist-get task :file))
         (marker (plist-get task :marker))
         ;; Clean headline for the link target: no TODO, no priority, no tags
         (link-target
          (if (and file marker (file-exists-p file))
              (with-current-buffer (find-file-noselect file)
                (goto-char marker)
                (org-task-scheduler/escape-link-text
                 (org-get-heading t t t))) ; remove tags, todo, priority
            (org-task-scheduler/escape-link-text task-name)))
         ;; Display text: exact original headline (not escaped)
         (link-display task-name))
    (insert
     (if org-task-scheduler/enable-links
         (format "%s %s: [[file:%s::*%s][%s]]\n"
                 prefix time-str file link-target link-display)
       (format "%s %s: %s\n"
               prefix time-str task-name)))))

(defun org-task-scheduler/check-tasks ()
  "Filter tasks based on schedule and deadline criteria and
categorize them based on conditions in dedicated Org Mode
buffer."
  (let* ((current-time (current-time))
	 (lead-time-format
	  (org-task-scheduler/m2h-format
	   (max
	    org-task-scheduler/minutes-past-deadline-cutoff
	    org-task-scheduler/minutes-past-schedule-time
	    org-task-scheduler/minutes-to-deadline-cutoff
	    org-task-scheduler/minutes-to-schedule-time)
	   ))
	 (tasks org-task-scheduler/tasks)
	 (org-buffer (get-buffer org-task-scheduler/buffer))
	 (tasks-categorized nil)) ; flag to track if any tasks were categorized

    ;; create a new buffer if it doesn't exist
    (unless org-buffer
      (setq org-buffer (generate-new-buffer org-task-scheduler/buffer)))

    (with-current-buffer org-buffer
      (org-mode)
      (erase-buffer) ; clear the buffer
      (set-buffer-file-coding-system 'utf-8-unix)
      (insert (format "#+TITLE: Tasks List as of %s\n" (format-time-string "%Y-%m-%d %H:%M:%S" (current-time))))

      ;; iterate over tasks
      (dolist (task tasks)
        (let* ((schedule-date-str (plist-get task :schedule-date))
               (deadline-date-str (plist-get task :deadline-date))
               (schedule-date (if schedule-date-str
                                  (org-time-string-to-time schedule-date-str)
                                nil))
               (deadline-date (if deadline-date-str
                                  (org-time-string-to-time deadline-date-str)
                                nil))
               (time-diff-schedule (if schedule-date
                                       (/ (- (float-time schedule-date) (float-time current-time)) 60)
                                     nil))
               (time-diff-deadline (if deadline-date
                                       (/ (- (float-time deadline-date) (float-time current-time)) 60)
                                     nil)))

          ;; check conditions independently for each task
	  (if (and deadline-date (<= (abs time-diff-deadline) org-task-scheduler/minutes-past-deadline-cutoff) (< time-diff-deadline 0))
	      ;; check if the entry missed deadline then insert
	      (progn
                (org-task-scheduler/insert-task-entry
                 "Missed Deadline by"
                 (format (concat lead-time-format " Hours") (/ (abs time-diff-deadline) 60))
                 task)
		(setq tasks-categorized t))
	    ;; otherwise (if the entry didn't miss deadline), check if it missed
	    ;; schedule then insert
	    (when (and schedule-date (<= (abs time-diff-schedule) org-task-scheduler/minutes-past-schedule-time) (< time-diff-schedule 0))
	      (progn
                (org-task-scheduler/insert-task-entry
                 "Missed Schedule by"
                 (format (concat lead-time-format " Hours") (/ (abs time-diff-schedule) 60))
                 task)
		(setq tasks-categorized t)))
	    )

          (when (and deadline-date (>= time-diff-deadline 0) (<= time-diff-deadline org-task-scheduler/minutes-to-deadline-cutoff))
            (progn
              (org-task-scheduler/insert-task-entry
               "Upcmng Deadline in"
               (format (concat lead-time-format " Hours") (/ time-diff-deadline 60))
               task)
              (setq tasks-categorized t)))

          (when (and schedule-date (>= time-diff-schedule 0) (<= time-diff-schedule org-task-scheduler/minutes-to-schedule-time))
            (progn
              (org-task-scheduler/insert-task-entry
               "Upcmng Schedule in"
               (format (concat lead-time-format " Hours") (/ time-diff-schedule 60))
               task)
              (setq tasks-categorized t))))))

    ;; display the Org Mode buffer if tasks were categorized
    (if tasks-categorized
        (progn
          (pop-to-buffer org-buffer)
          (org-task-scheduler/sort-lines)
	  (goto-char (point-max))
          (when (functionp 'org-task-scheduler/reminder-action)
            (org-task-scheduler/reminder-action))
          (message "Tasks categorized in the dedicated Org Mode buffer (%s)." org-task-scheduler/buffer))
      ;; if no tasks matched, delete the buffer and raise a message
      (kill-buffer org-buffer)
      (message "No tasks meet the missed and upcoming time criteria."))))


(provide 'org-task-scheduler)

;; Local Variables:
;; coding: utf-8
;; End:
;;; org-task-scheduler.el ends here
