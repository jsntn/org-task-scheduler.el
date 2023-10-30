# org-task-scheduler.el

This package provides automated task scheduling and deadline tracking in Org Mode.

## Features

- Scans Org files to identify upcoming and missed scheduled/deadline tasks
- Categorizes tasks into dedicated sections in a Task List buffer 
- Provides configuration for inclusion/exclusion criteria
- Notifications and alerts for upcoming and missed tasks
- Easy to customize and extend

## Installation

org-task-scheduler.el can be installed using [straight.el](https://github.com/radian-software/straight.el). To install, add the following to your Emacs configuration file:

```emacs
(use-package org-task-scheduler
  :straight (:host github :repo "jsntn/org-task-scheduler.el"))
```

Or manually add this file to your Emacs load path.

## Usage

`M-x org-task-scheduler/scan-tasks`

Scans all agenda files based on configured criteria.

`M-x org-task-scheduler/check-tasks`

Filter tasks based on schedule and deadline criteria and
categorize them based on conditions in dedicated Org Mode
buffer.

## Configuration

Customize the scanning criteria by setting these variables:

- `org-task-scheduler/included-tags`
- `org-task-scheduler/excluded-tags` 
- `org-task-scheduler/included-todo-keywords`
- `org-task-scheduler/excluded-todo-keywords`
- `org-task-scheduler/included-files`
- `org-task-scheduler/excluded-files`

And time window criteria:

- `org-task-scheduler/minutes-to-schedule-time` 
- `org-task-scheduler/minutes-to-deadline-cutoff`
- `org-task-scheduler/minutes-past-schedule-time`
- `org-task-scheduler/minutes-past-deadline-cutoff`

See full documentation in the code comments.

## Contributing

Contributions are welcome! Please open issues or submit pull requests.

## License

This package is licensed under the GPL 3.0 License. See LICENSE for details.