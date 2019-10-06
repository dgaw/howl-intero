import command, interact from howl
intero = bundle_load 'intero'

register_commands = ->

  command.register
    name: 'intero-start',
    description: 'Start the Haskell Intero process'
    handler: ->
      intero.start_intero!

  command.register
    name: 'intero-show-type',
    description: 'Show the type of the selected expression using Intero'
    -- input: interact.read_text
    handler: () ->
      intero.show_type!

register_commands!

unload = ->
  command.unregister 'intero-start'
  command.unregister 'intero-show-type'

return {
  info:
    author: 'Damian Gaweda'
    description: 'Haskell Intero support',
    license: 'MIT',
  :unload
}
