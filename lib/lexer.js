(function() {
  var tokenDefs;

  tokenDefs = [['-', /^(?:[ \t]+|[⍝\#].*)+/], ['newline', /^[\n\r]+/], ['separator', /^[◇⋄]/], ['number', /^¯?(?:0x[\da-f]+|\d*\.?\d+(?:e[+¯]?\d+)?|¯)(?:j¯?(?:0x[\da-f]+|\d*\.?\d+(?:e[+¯]?\d+)?|¯))?/i], ['string', /^(?:'(?:[^\\']|\\.)*'|"(?:[^\\"]|\\.)*")+/], ['', /^[\(\)\[\]\{\}:;←]/], ['embedded', /^«[^»]*»/], ['symbol', /^(?:∘\.|⎕?[a-z_][0-9a-z_]*|[^¯'":«»])/i]];

  this.tokenize = function(aplCode) {
    var col, line, stack;
    line = col = 1;
    stack = ['{'];
    return {
      next: function() {
        var a, m, re, startCol, startLine, t, type, _i, _len, _ref;
        while (true) {
          if (!aplCode) {
            return {
              type: 'eof',
              value: '',
              startLine: line,
              startCol: col,
              endLine: line,
              endCol: col
            };
          }
          startLine = line;
          startCol = col;
          type = null;
          for (_i = 0, _len = tokenDefs.length; _i < _len; _i++) {
            _ref = tokenDefs[_i], t = _ref[0], re = _ref[1];
            if (!(m = aplCode.match(re))) {
              continue;
            }
            type = t || m[0];
            break;
          }
          if (!type) {
            throw Error("Lexical error at " + line + ":" + col);
          }
          a = m[0].split('\n');
          line += a.length - 1;
          col = (a.length === 1 ? col : 1) + a[a.length - 1].length;
          aplCode = aplCode.substring(m[0].length);
          if (type !== '-') {
            if (type === '(' || type === '[' || type === '{') {
              stack.push(type);
            } else if (type === ')' || type === ']' || type === '}') {
              stack.pop();
            }
            if (type !== 'newline' || stack[stack.length - 1] === '{') {
              return {
                type: type,
                startLine: startLine,
                startCol: startCol,
                value: m[0],
                endLine: line,
                endCol: col
              };
            }
          }
        }
      }
    };
  };

}).call(this);