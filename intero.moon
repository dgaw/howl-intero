{:app, :breadcrumbs, :Buffer, :Project} = howl
{:BufferPopup, :ProcessBuffer} = howl.ui
{:Process} = howl.io
{:min, :max} = math
import PropertyTable from howl.util

local proc -- Intero process
local port -- TCP port number used for communication with Intero

class InteroBuffer extends ProcessBuffer
  pump: =>
    on_stdout = (read) ->
      @_append read
      if port == nil
        port = @text\umatch r'Intero-Service-Port: (\\d+)'
        log.info "Ok, found Intero port" if port != nil

    on_stderr = (read) -> @_append read, 'stderr'

    @process\pump on_stdout, on_stderr

    port = nil
    @title = "#{@base_title} (done)"

    unless @destroyed
      @modify ->
        @append '\n' unless @lines[#@lines].is_blank
        @append "=> Process terminated (#{@process.exit_status_string})", 'comment'

    editor = app\editor_for_buffer @
    editor.indicator.activity.visible = false if editor

    log_msg = "=> Intero process terminated (#{@process.exit_status_string})"
    log[@process.exited_normally and 'info' or 'warn'] log_msg

    if #@lines == 2 -- no output
      app\close_buffer @

get_project_root = ->
  buffer = app.editor and app.editor.buffer
  file = buffer.file or buffer.directory
  error "No file associated with the current view" unless file
  project = Project.get_for_file file
  error "No project associated with #{file}" unless project
  return project.root

intero_ready = ->
  proc != nil and not proc.exited and port != nil

send_command = (cmd) ->
  if not intero_ready!
    error "Intero is not running. Start it with alt_x intero-start."

  -- This is a work-around for the lack of socket support in Howl.
  -- TODO: Bash is required for this to work so not really portable.
  exec_cmd = 'exec 3<>/dev/tcp/localhost/' .. port ..
             ' && echo -e "' .. cmd .. '\n" >&3' ..
             ' && cat <&3'
  stdout, stderr, p  = Process.execute exec_cmd

  if not p.successful
    error "Error sending the command to Intero: " .. stderr

  if stdout.stripped.ulen == 0
    error 'Intero returned nothing for the command: ' .. cmd

  stdout

start_intero = ->
  if intero_ready!
    error 'Intero is already running!'

  -- Intero quits immediately if it detects that it's running in a non-interactive shell.
  -- The 'script' hack below simulates an interactive shell.
  -- TODO: script is from util-linux so it's not really portable :/
  fake_interactive = (cmd) -> "script --return --quiet -c \"" .. cmd .."\" /dev/null"

  shell = howl.sys.env.SHELL or '/bin/sh'
  proc = Process {
    cmd: fake_interactive "stack ghci --with-ghc intero",
    :shell,
    read_stdout: true,
    read_stderr: true,
    working_directory: get_project_root!,
    -- working_directory: '/home/damian/Projects/relink',
  }

  breadcrumbs.drop!
  buf = InteroBuffer proc, { title: "Intero process" }
  editor = app\add_buffer buf
  editor.cursor\eof!

  buf\pump!

show_type = ->
  editor = app.editor
  file = editor.buffer.file
  error "No file associated with the current view" unless file

  pos_to_line_col = (pos) ->
    line = editor.buffer.lines\at_pos pos
    col = pos - line.start_pos + 1
    return line.nr, col

  start_line = editor.cursor.line
  start_col = editor.cursor.column_index
  end_line = start_line
  end_col = start_col

  unless editor.selection.empty
    selection = editor.selection
    start_line, start_col = pos_to_line_col (min selection.anchor, selection.cursor)
    end_line, end_col = pos_to_line_col (max selection.anchor, selection.cursor)

  cmd = "type-at #{file} #{start_line} #{start_col} #{end_line} #{end_col} it"
  -- log.info 'Sending Intero command: ' .. cmd
  ret = send_command cmd

  type_buf = Buffer! -- howl.mode.by_name('haskell')
  type_buf.text = ret
  app.editor\show_popup BufferPopup type_buf

PropertyTable {
  :start_intero,
  :show_type,
}
