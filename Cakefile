{existsSync} = require 'path'
{statSync, readdirSync} = require 'fs'
{execFile} = require 'child_process'

exec = (cmd, args, opts, cont) ->
  execFile cmd, args, opts, (error, stdout, stderr) ->
    if stdout then console.info stdout
    if stderr then console.info stderr
    throw error if error
    cont()

newer = (x, y) ->
  (not existsSync y) or statSync(x).mtime.getTime() > statSync(y).mtime.getTime()

task 'build', ->
  filenames = for f in readdirSync 'src' when f.match(/^\w.*\.coffee$/) and newer('src/' + f, 'lib/' + f.replace(/\.coffee$/, '.js')) then 'src/' + f
  if filenames.length
    console.info "Compiling #{filenames.join ' '}..."
    exec 'coffee', ['-o', 'lib', '-c'].concat(filenames), {}, ->
      if newer 'lib/grammar.js', 'lib/parser.js'
        console.info 'Generating parser...'
        exec 'node', ['grammar.js'], {cwd: 'lib'}, ->
          console.info 'Done'