import json
import sequtils
import strutils
import tables


type
  ContextKind* = enum ## possible Context types
    CArray,
    CObject,
    CValue

  ## Context used to render a mustache template
  Context* = ref ContextObj
  ContextObj = object
    case kind*: ContextKind
    of CValue:
      val: JsonNode
    of CArray:
      elems: seq[Context]
    of CObject:
      fields: Table[string, Context]

## Builders

proc newContext*(j : JsonNode = nil): Context =
  ## Create a new Context based on a JsonNode object
  new(result)
  if j == nil:
    result.kind = CObject
    result.fields = initTable[string, Context](4)
  else:
    case j.kind
    of JObject:
      result.kind = CObject
      result.fields = initTable[string, Context](4)
      for key, val in pairs(j.fields):
        result.fields[key] = newContext(val)
    of JArray:
      result.kind = CArray
      result.elems = @[]
      for val in j.elems:
        result.elems.add(newContext(val))
    else:
      result.kind = CValue
      result.val = j

proc newArrayContext*(): Context =
  ## Create a new Context of kind CArray
  new(result)
  result.kind = CArray
  result.elems = @[]

## Getters

proc `[]`*(c: Context, key: string): Context =
  ## Return the Context associated with `key`.
  ## If the Context at `key` does not exist, return nil.
  assert(c != nil)
  if c.kind != CObject: return nil
  if c.fields.hasKey(key): return c.fields[key] else: return nil

proc `[]`*(c: Context, index: int): Context =
  assert(c != nil)
  if c.kind != CArray: return nil else: return c.elems[index]

## Setters

proc `[]=`*(c: var Context, key: string, value: Context) =
  ## Assign a context `value` to `key` in context `c`
  assert(c.kind == CObject)
  c.fields[key] = value

proc `[]=`*(c: var Context, key: string, value: JsonNode) =
  ## Convert and assign `value` to `key` in `c`
  assert(c.kind == CObject)
  c[key] = newContext(value)

proc `[]=`*(c: var Context; key: string, value: BiggestInt) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = newContext(newJInt(value))

proc `[]=`*(c: var Context; key: string, value: string) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = newContext(newJString(value))

proc `[]=`*(c: var Context; key: string, value: float) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = newContext(newJFloat(value))

proc `[]=`*(c: var Context; key: string, value: bool) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = newContext(newJBool(value))

proc `[]=`*(c: var Context, key: string, value: openarray[Context]) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  var contextList = newArrayContext()
  for v in value:
    contextList.elems.add(v)
  c[key] = contextList

proc `[]=`*(c: var Context, key: string, value: openarray[string]) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = map(value, proc(x: string): Context = newContext(newJString(x)))

proc `[]=`*(c: var Context, key: string, value: openarray[int]) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = map(value, proc(x: int): Context = newContext(newJInt(x)))

proc `[]=`*(c: var Context, key: string, value: openarray[float]) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = map(value, proc(x: float): Context = newContext(newJFloat(x)))

proc `[]=`*(c: var Context, key: string, value: openarray[bool]) =
  ## Assign `value` to `key` in Context `c`
  assert(c.kind == CObject)
  c[key] = map(value, proc(x: bool): Context = newContext(newJBool(x)))

## Printers

proc `$`*(c: Context): string =
  ## Return a string representing the context. Useful for debugging
  result = "Context->[kind: " & $c.kind
  case c.kind
  of CValue: result &= "\nval: " & $c.val
  of CArray:
    var strArray = map(c.elems, proc(c: Context): string = $c)
    result &= "\nelems: [" & join(strArray, ", ") & "]"
  of CObject:
    var strArray : seq[string] = @[]
    for key, val in pairs(c.fields):
      strArray.add(key & ": " & $val)
    result &= "\nfields: {" & join(strArray, ", ") & "}"
  result &= "\n]"

proc toString*(c: Context): string =
  ## Return string representation of `c` relevant to mustache
  if c != nil:
    if c.kind == CValue:
      case c.val.kind
      of JString:
       return c.val.str
      of JFloat:
       return c.val.fnum.formatFloat(ffDefault, 0)
      of JInt:
       return $c.val.num
      of JNull:
       return ""
      of JBool:
       return if c.val.bval: "true" else: ""
      else:
       return $c.val
    else:
      return $c
  else:
    return ""

proc len*(c: Context): int =
  if c.kind == CArray: result = c.elems.len
  else: discard

converter toBool*(c: Context): bool =
  assert(c.kind == CValue)
  case c.val.kind
  of JBool: result = c.val.bval
  of JNull: result = false
  of JString: result = c.val.str != ""
  else: result = true
