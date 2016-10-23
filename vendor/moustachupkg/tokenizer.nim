import sequtils
import strutils

type
  TokenType* {.pure.} = enum
    rawtext,
    escapedvariable,
    unescapedvariable,
    section,
    invertedsection,
    comment,
    partial,
    ender,
    indenter

  Token* = tuple[tokentype: TokenType, value: string]


proc left_side_empty(tmplate: string, pivotindex: int): tuple[empty: bool, newlineindex: int] =
  var ls_i = 0
  var ls_empty = false
  var i = pivotindex - 1
  while i > -1 and tmplate[i] in {' ', '\t'}: dec(i)
  if (i == -1) or (tmplate[i] == '\l'):
    ls_i = i
    ls_empty = true
  return (empty: ls_empty, newlineindex: ls_i)


iterator tokenize*(tmplate: string): Token =
  let opening = "{{"
  var pos = 0

  while pos < tmplate.len:
    let originalpos = pos
    var closing = "}}"

    # find start of tag
    var opening_index = tmplate.find(opening, start=pos)
    if opening_index == -1:
      yield (tokentype: TokenType.rawtext, value: tmplate[pos..high(tmplate)])
      break

    #Check if the left side is empty
    var left_side = left_side_empty(tmplate, opening_index)
    var ls_empty = left_side.empty
    var ls_i = left_side.newlineindex

    #Deal with text before tag
    var beforetoken = (tokentype: TokenType.rawtext, value: "")
    if opening_index > pos:
      #safe bet for now
      beforetoken.value = tmplate[pos..opening_index-1]

    pos = opening_index + opening.len

    if not (pos < tmplate.len):
      yield (tokentype: TokenType.rawtext, value: tmplate[opening_index..high(tmplate)])
      break

    #Determine TokenType
    var tt = TokenType.escapedvariable

    case tmplate[pos]
    of '!':
      tt = TokenType.comment
      pos += 1
    of '&':
      tt = TokenType.unescapedvariable
      pos += 1
    of '{':
      tt = TokenType.unescapedvariable
      pos += 1
      closing &= "}"
    of '#':
      tt = TokenType.section
      pos += 1
    of '^':
      tt = TokenType.invertedsection
      pos += 1
    of '/':
      tt = TokenType.ender
      pos += 1
    of '>':
      tt = TokenType.partial
      pos += 1
    else:
      tt = TokenType.escapedvariable

    #find end of tag
    var closingindex = tmplate.find(closing, start=pos)
    if closingindex == -1:
      if beforetoken.value != "": yield beforetoken
      yield (tokentype: TokenType.rawtext, value: tmplate[opening_index..pos-1])
      continue

    #Check if the right side is empty
    var rs_i = 0
    var rs_empty = false
    var i = 0
    if ls_empty:
      i = closingindex + closing.len
      while i < tmplate.len and tmplate[i] in {' ', '\t'}: inc(i)
      if i == tmplate.len:
        rs_i = i - 1
        rs_empty = true
      elif tmplate[i] == '\c' and (i+1 < tmplate.len) and (tmplate[i+1] == '\l'):
        rs_i = i + 1
        rs_empty = true
      elif tmplate[i] == '\l':
        rs_i = i
        rs_empty = true
      else:
        discard

    if tt in [TokenType.comment, TokenType.section,
              TokenType.invertedsection, TokenType.ender, TokenType.partial]:
      # Standalone tokens
      if rs_empty:
        if beforetoken.value != "":
          beforetoken.value = tmplate[originalpos..ls_i]
          yield beforetoken

        if tt == TokenType.partial:
          if ls_i+1 <= opening_index-1:
            yield (tokentype: TokenType.indenter, value: tmplate[ls_i+1..opening_index-1])

        yield (tokentype: tt, value: tmplate[pos..closingindex-1].strip)
        pos = rs_i + 1 # remove new line of this line
      else:
        if beforetoken.value != "": yield beforetoken
        yield (tokentype: tt, value: tmplate[pos..closingindex-1].strip)
        pos = closingindex + closing.len
    else:
      if beforetoken.value != "": yield beforetoken
      yield (tokentype: tt, value: tmplate[pos..closingindex-1].strip)
      pos = closingindex + closing.len
