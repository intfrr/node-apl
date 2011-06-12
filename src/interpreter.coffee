{builtins} = require './builtins'
{inherit, trampoline, cps, cpsify} = require './helpers'
{parse} = require './parser'



exports.exec = (code, ctx, callback) ->
  if typeof ctx is 'function' and not callback? then callback = ctx; ctx = undefined
  ctx ?= inherit builtins
  callback ?= (err) -> if err then throw err
  ast = parse code

  try
    trampoline -> exec0 ast, ctx, callback
  catch err
    callback err

  return



exec0 = (ast, ctx, callback) ->
  # Evaluate a branch of the abstract syntax tree
  # `ctx' holds variable bindings
  switch ast[0]

    when 'body'
      i = 1
      r = 0
      F = ->
        if i < ast.length
          -> exec0 ast[i], ctx, (err, r0) ->
            if err then return -> callback err
            r = r0; i++; F
        else
          -> callback null, r

    when 'num'
      -> callback null, parseFloat ast[1].replace /¯/, '-'

    when 'str'
      -> callback null, eval(ast[1]).split ''

    when 'index'
      -> exec0 ast[1], ctx, (err, indexable) ->
        if err then return -> callback err
        i = 2
        indices = []
        F = ->
          if i < ast.length
            -> exec0 ast[i], ctx, (err, index) ->
              if err then return -> callback err
              indices.push index; i++; F
          else
            if typeof indexable is 'function'
              -> callback null, cps (a, b, _, callback1) ->
                -> cpsify(indexable) a, b, indices, callback1
            else
              -> cpsify(ctx['⌷']) indices, indexable, null, callback

    when 'assign'
      -> exec0 ast[2], ctx, (err, value) ->
        if err then return -> callback err
        name = ast[1]
        if typeof ctx[name] is 'function' and ctx[name].isNiladic then ctx[name] value else ctx[name] = value # todo: cpsify
        -> callback null, value

    when 'sym'
      name = ast[1]; value = ctx[name]
      if not value? then return -> callback Error "Symbol #{name} is not defined."
      if typeof value is 'function' and value.isNiladic then value = value() # todo: cpsify
      -> callback null, value

    when 'lambda'
      -> callback null, cps (a, b, _, callback1) ->
        ctx1 = inherit ctx
        # Bind formal parameter names 'alpha' and 'omega' to the left and right argument
        if b?
          ctx1['⍺'] = a
          ctx1['⍵'] = b
        else
          ctx1['⍺'] = 0
          ctx1['⍵'] = a
        -> exec0 ast[1], ctx1, (err, res) ->
          -> callback1 err, res

    when 'seq'
      if ast.length is 1 then return -> callback null, 0
      a = []
      i = ast.length - 1
      F = ->
        if i >= 1
          -> exec0 ast[i], ctx, (err, result) ->
            if err then return -> callback err
            a.unshift result; i--; F
        else

          # Form vectors from sequences of data ("strands")
          i = 0
          while i < a.length
            if typeof a[i] isnt 'function'
              j = i + 1
              while j < a.length and typeof a[j] isnt 'function' then j++
              if j - i > 1
                a[i...j] = [a[i...j]]
            i++

          # Apply infix operators
          i = 0
          F = ->
            if i < a.length - 2
              if (typeof a[i] is 'function') and (typeof a[i+1] is 'function') and (a[i+1].isInfixOperator) and (typeof a[i+2] is 'function')
                -> cpsify(a[i+1]) a[i], a[i+2], null, (err, result) ->
                  if err then return -> callback err
                  a[i..i+2] = [result]
                  F
              else
                i++; F
            else

              # Apply postfix operators
              i = 0
              F = ->
                if i < a.length - 1
                  if (typeof a[i] is 'function') and (typeof a[i+1] is 'function') and a[i+1].isPostfixOperator
                    -> cpsify(a[i+1]) a[i], null, null, (err, result) ->
                      if err then return -> callback err
                      a[i..i+1] = [result]
                      F
                  else
                    i++; F
                else

                  # Apply prefix operators
                  i = a.length - 2
                  F = ->
                    if i >= 0
                      if (typeof a[i] is 'function') and a[i].isPrefixOperator and (typeof a[i+1] is 'function')
                        -> cpsify(a[i]) a[i+1], null, null, (err, result) ->
                          if err then return -> callback err
                          a[i..i+1] = [result]
                          F
                      else
                        i--; F
                    else

                      # Apply functions
                      F = ->
                        if a.length > 1
                          if typeof a[a.length - 1] is 'function'
                            -> callback Error 'Trailing function in expression'
                          else
                            y = a.pop(); f = a.pop()
                            if a.length is 0 or typeof a[a.length - 1] is 'function'
                              # apply monadic function
                              -> cpsify(f) y, null, null, (err, result) ->
                                if err then return -> callback err
                                a.push result
                                F
                            else
                              # apply dyadic function
                              x = a.pop()
                              -> cpsify(f) x, y, null, (err, result) ->
                                if err then return -> callback err
                                a.push result
                                F
                        else
                          -> callback null, a[0]

    else
      -> callback Error 'Unrecognized AST node type: ' + ast[0]