import sequtils, strutils, re

type
  BlockType* = enum
    undefinedBlock,
    paragraph,
    header,
    headerEmpty,
    header1,
    header2,
    header3,
    header4,
    header5,
    header6,
    setextHeader,
    themanticBreak,
    indentedCodeBlock,
    fencedCodeBlockBack,
    fencedCodeBlockTild,
    fencedCodeBlock,
    htmlBlock1,
    htmlBlock2,
    htmlBlock3,
    htmlBlock4,
    htmlBlock5,
    htmlBlock6,
    htmlBlock7,
    htmlBlock,
    linkReference,
    blockQuote,
    unOrderedList,
    unOrderedTightList,
    unOrderedLooseList,
    orderedList,
    orderedTightList,
    orderedLooseList,
    list,
    emptyLine,
    none

type
  BlockKind* = enum
    containerBlock,
    leafBlock,
    fencedCode,
    linkRef

  Block* = ref BlockObj
  BlockObj = object
    case kind*: BlockKind

    of containerBlock:
      containerType*: BlockType
      children*: seq[Block]

    of leafBlock:
      leafType*: BlockType
      raw*: string
    
    of fencedCode:
      codeType*: BlockType
      codeAttr*: string
      codeText*: string
    
    of linkRef:
      linkLabel*: string
      linkUrl*: string
      linkTitle*: string

  
  FlagContainer* = ref FlagObj
  FlagObj = object
    flagBlockQuote*: bool
    flagIndentedCodeBlock*: bool
    flagFencedCodeBlockBack*: bool
    flagFencedCodeBlockTild*: bool
    openingFenceLength*: int
    fencedCodeBlocksdepth*: int
    flagHtmlBlock1*: bool
    flagHtmlBlock2*: bool
    flagHtmlBlock3*: bool
    flagHtmlBlock4*: bool
    flagHtmlBlock5*: bool
    flagHtmlBlock6*: bool
    flagHtmlBlock7*: bool
    flagLinkReference*: bool
    flagUnorderedList*: bool
    uldepth*: int
    flagOrderedList*: bool
    oldepth*: int
    hasEmptyLine*: bool
    afterEmptyLine*: bool
    looseUnordered*: bool
    looseOrdered*: bool

proc newFlag*(): FlagContainer =
  FlagContainer(
    flagBlockQuote: false,
    flagIndentedCodeBlock: false,
    flagFencedCodeBlockBack: false,
    flagFencedCodeBlockTild: false,
    flagHtmlBlock1: false,
    flagHtmlBlock2: false,
    flagHtmlBlock3: false,
    flagHtmlBlock4: false,
    flagHtmlBlock5: false,
    flagHtmlBlock6: false,
    flagHtmlBlock7: false,
    flagLinkReference: false,
    flagUnorderedList: false,
    uldepth: 0,
    flagOrderedList: false,
    oldepth: 0,
    hasEmptyLine: false,
    afterEmptyLine: false,
    looseUnordered: false,
    looseOrdered: false
  )

let
  reThematicBreak* = re" {0,3}(\*{3,}|-{3,}|_{3,})$"
  reSetextHeader* = re"^ {0,3}(=+|-+)\s*$"
  reBreakOrHeader* = re" {0,3}(-{3,}) *$"
  reAtxHeader* = re" {0,3}(#{1,6}) "
  reAnotherAtxHeader* = re"^#{1,6}$"
  reBlockQuote* = re" {0,3}> {0,1}"
  reBlockQuoteTab* = re" {0,3}>\t+"
  reUnorderedList* = re" {0,3}(-|\+|\*)( |\t)"
  reOrderedList* = re" {0,3}[0-9]{1,9}(\.|\))( |\t)+"
  reIndentedCodeBlock* = re"\s{4,}\S+"
  reTabStart* = re" *\t+"
  reBreakIndentedCode* = re" {0,3}\S"
  reFencedCodeBlockBack* = re"^ {0,3}`{3,}[^`]*$"
  reFencedCodeBlockTild* = re"^ {0,3}~{3,}[^~]*~*$"

  reHtmlBlock1Begins* = re" {0,3}<(script|pre|style|textarea)( |>|$)"
  reHtmlBlock1Ends*   = re"</script>|</pre>|</style>|</textarea>"
  reHtmlBlock2Begins* = re" {0,3}<!--"
  reHtmlBlock2Ends*   = re"-->"
  reHtmlBlock3Begins* = re" {0,3}<\?"
  reHtmlBlock3Ends*   = re"\?>"
  reHtmlBlock4Begins* = re" {0,3}<![A-Z]"
  reHtmlBlock4Ends*   = re">"
  reHtmlBlock5Begins* = re" {0,3}<!\[CDATA\["
  reHtmlBlock5Ends*   = re"\]\]>"
  reHtmlBlock6Begins* = re(" {0,3}(<|</)(address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)( |\n|>|/>)", {reIgnoreCase})
  reHtmlBlock7Begins* = re(" {0,3}(<|</)[a-zA-Z][a-zA-Z0-9-]*( [a-zA-Z_:][a-zA-Z0-9|_|.|:|-]*)*( {0,1}= {0,1}(|'|\")[a-zA-Z]+(|'|\"))* */*(>|/>) *$")

  reLinkRef = re" {0,3}\[\s*.*\s*]:(\s*\n?\s*)"

  reEntity* = re"&[a-zA-Z0-9#]+;"

proc delWhitespace*(line: string): string =
  var str: string
  for c in line:
    if c != ' ': str.add(c)
  return str

proc countWhitespace*(line: string): int =
  var i = 0
  for c in line:
    if c == ' ': i.inc
    else: return i
  return i

proc delULMarker*(line: var string): (int, string) =
  var n: int
  var s: string
  var flag = false
  for i, c in line:
    if c == ' ': continue
    elif c == '-' or c == '+' or c == '*':
      if flag:
        n = i
        s = line[i..^1]
        return (n, s)
      else:
        flag = true
        continue
    else:
      n = i
      s = line[i..^1]
      return (n, s)


proc deleteUntilTab*(line: string): string =
  var flag = false
  for c in line:
    if flag: result.add(c)
    if c == ' ': continue
    elif c == '\t': flag = true

proc countTab*(line: string): int =
  var i: int
  for c in line:
    if c == '\t': i.inc
    else: return i

proc delWhitespaceAndTab*(line: string): string =
  var flag = false
  for c in line:
    if flag:
      result.add(c)
    elif c == ' 'or c == '\t': continue
    else:
      result.add(c)
      flag = true

proc countSpaceWithTab*(line: string): int =
  var i: int
  for c in line:
    if c == ' ': i.inc
    elif c == '\t': i += 3
    else: continue
  return i

proc countBacktick*(line: string): int =
  var i: int
  for c in line:
    if c == ' ': continue
    elif c == '`': i.inc
    else: return i
  return i

proc countTild*(line: string): int =
  var i: int
  for c in line:
    if c == ' ': continue
    elif c == '~': i.inc
    else: return i
  return i

proc delSpaceAndFence*(line: string): string =
  var flag = false
  for c in line:
    if flag:
      result.add(c)
    elif c == ' ' or c == '`' or c == '~': continue
    else:
      flag = true
      result.add(c)

proc takeAttr*(line: string): string =
  let s = line.splitWhitespace
  return s[0]

proc openAtxHeader*(line: string): Block =
  var s = line.splitWhitespace
  let l = s.len()
  let marker = s[0]
  if s[l-1].all(proc(c: char): bool = c == '#'):
    s.delete(l-1, l-1)
  s.delete(0,0)
  let str = s.join(" ")

  case marker:
    of "#":
      return Block(kind: leafBlock, leafType: header1, raw: str)
    of "##":
      return Block(kind: leafBlock, leafType: header2, raw: str)
    of "###":
      return Block(kind: leafBlock, leafType: header3, raw: str)
    of "####":
      return Block(kind: leafBlock, leafType: header4, raw: str)
    of "#####":
      return Block(kind: leafBlock, leafType: header5, raw: str)
    of "######":
      return Block(kind: leafBlock, leafType: header6, raw: str)

proc openAnotherAtxHeader*(line: string): Block =
  case line
    of "#":
      return Block(kind: leafBlock, leafType: header1, raw: "")
    of "##":
      return Block(kind: leafBlock, leafType: header2, raw: "")
    of "###":
      return Block(kind: leafBlock, leafType: header3, raw: "")
    of "####":
      return Block(kind: leafBlock, leafType: header4, raw: "")
    of "#####":
      return Block(kind: leafBlock, leafType: header5, raw: "")
    of "######":
      return Block(kind: leafBlock, leafType: header6, raw: "")

proc openCodeBlock*(blockType: BlockType, atr: string, lines: string): Block =
  return Block(kind: fencedCode, codeType: blockType, codeAttr: atr, codeText: lines)

proc openSetextHeader*(n: int, lineBlock: string): Block =
  if n == 1:
    return Block(kind: leafBlock, leafType: header1, raw: lineBlock)
  else:
    return Block(kind: leafBlock, leafType: header2, raw: lineBlock)

proc openThemanticBreak*(): Block =
  return Block(kind: leafBlock, leafType: themanticBreak, raw: "")

proc openHtmlBlock*(lineBlock: string): Block =
  return Block(kind: leafBlock, leaftype: htmlblock, raw: lineBlock) 

proc openLinkReference*(lineBlock: string): Block =
  return Block(kind: leafBlock, leaftype: linkReference, raw: lineBlock)

proc openBlockQuote*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: blockQuote, children: mdast)

proc openList*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: list, children: mdast)

proc openLooseUL*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: unOrderedLooseList, children: mdast)

proc openTightUL*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: unOrderedTightList, children: mdast)

proc openLooseOL*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: orderedLooseList, children: mdast)

proc openTightOL*(mdast: seq[Block]): Block =
  Block(kind: containerBlock, containerType: orderedTightList, children: mdast)

proc openHTML*(lineBlock: string): Block =
  Block(kind: leafBlock, leafType: htmlBlock, raw: lineBlock)



type linkKind = enum
  toLabel
  skipToUrl
  toUrl
  toUrlLT
  skipToTitle
  toTitleDouble
  toTitleSingle
  toTitlePare
  afterTitle

proc openParagraph*(lineBlock: var string): seq[Block] =
  
  if lineBlock.startsWith(reLinkRef):

    block linkDetecting:

      while true:

        var
          label: string
          url: string
          title: string
          urlEndPos: int
          titleEndPos: int
          numOpenP: int
          numCloseP: int
          isAfterBreak = false
          isAfterBS = false
          isAfterWS = false
          isUrlLT = false
          nextLoop = false
          flag = toLabel

        for i, c in lineBlock:
          if i == 0: continue

          case flag
          of toLabel:
            if c == '[' and lineBlock[i-1] != '\\': break linkDetecting
            elif c == ']' and lineBlock[i-1] != '\\':
              flag = skipToUrl
              continue
            elif c == '\\':
              continue
            else:
              label.add(c)
              continue
          
          of skipToUrl:
            if c == ':' or c == ' ' or c == '\n': continue
            elif c == '<':
              flag = toUrlLT
              isUrlLT = true
              continue
            else:
              url.add(c)
              flag = toUrl
              continue
          
          of toUrlLT:
            if c == '\n': break linkDetecting
            elif c == '<' and lineBlock[i-1] != '\\': break linkDetecting
            elif c == '>' and lineBlock[i-1] != '\\':
              urlEndPos = i
              flag = skipToTitle
              continue
            elif c == ' ':
              url.add("%20")
              continue
            else:
              url.add(c)
              continue
          
          of toUrl:
            if c == '(' and lineBlock[i-1] != '\\':
              numOpenP.inc
              url.add(c)
            elif c == ')' and lineBlock[i-1] != '\\':
              numCloseP.inc
              url.add(c)
            elif c == '\\':
              isAfterBS = true
              continue
            elif c == ' ':
              if numOpenP == numCloseP:
                urlEndPos = i
                flag = skipToTitle
                isAfterWS = true
                continue
              else:
                break linkDetecting
            elif c == '\n':
              if numOpenP == numCloseP:
                urlEndPos = i
                flag = skipToTitle
                isAfterBreak = true
                continue
              else:
                break linkDetecting
            elif c == '*':
              isAfterBS = false
              url.add(c)
            else:
              if isAfterBS:
                isAfterBS = false
                url.add("%5C" & c)
              else:
                url.add(c)
                continue
          
          of skipToTitle:
            if c == ' ':
              isAfterWS = true
              continue 
            elif c == '\n':
              if isAfterBreak:
                result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: ""))
                lineBlock.delete(0, urlEndPos)
                break linkDetecting
              else:
                isAfterBreak = true
                continue
            elif c == '"':
              if isAfterWS or isAfterBreak:
                title.add(c)
                flag = toTitleDouble
                isAfterWS = false
                continue
              else:
                break linkDetecting
            elif c == '\'':
              if isAfterWS or isAfterBreak:
                title.add(c)
                flag = toTitleSingle
                isAfterWS = false
                continue
              else: break linkDetecting
            elif c == '(':
              if isAfterWS or isAfterBreak:
                title.add(c)
                flag = toTitleDouble
                isAfterWS = false
                continue
              else: break linkDetecting
            else:
              if isAfterBreak:
                result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: ""))
                lineBlock.delete(0, urlEndPos)
                nextLoop = true
                break 
              else:
                break linkDetecting
          
          of toTitleDouble:
            if c == '"' and not(isAfterBS):
              title.add(c)
              titleEndPos = i
              flag = afterTitle
              continue
            elif c == '"' and isAfterBS:
              title.add("&quot;")
              isAfterBS = false
              continue
            elif c == '\\':
              isAfterBS = true
              continue
            else:
              if isAfterBS:
                isAfterBS = false
                title.add("\\" & c)
                continue
              else:
                title.add(c)
                continue

          of toTitleSingle:
            if c == '\'' and not(isAfterBS):
              title.add(c)
              titleEndPos = i
              flag = afterTitle
              continue
            elif c == '\'' and isAfterBS:
              title.add(c)
              isAfterBS = false
              continue
            elif c == '\\':
              isAfterBS = true
              continue
            else:
              if isAfterBS:
                isAfterBS = false
                title.add("\\" & c)
                continue
              else:
                title.add(c)
                continue

          of toTitlePare:
            if c == '(' and not(isAfterBS): break linkDetecting
            if c == ')' and not(isAfterBS):
              title.add(c)
              titleEndPos = i
              flag = afterTitle
              continue
            elif c == ')' and isAfterBS:
              title.add(c)
              isAfterBS = false
              continue
            elif c == '\\':
              isAfterBS = true
              continue
            else:
              if isAfterBS:
                isAfterBS = false
                title.add("\\" & c)
                continue
              else:
                title.add(c)
                continue
            if c == '(' and lineBlock[i-1] != '\\': break linkDetecting
            elif c == ')' and lineBlock[i-1] != '\\':
              title.add(c)
              titleEndPos = i
              flag = afterTitle
              continue
            else:
              title.add(c)
              continue
          
          of afterTitle:
            if c == ' ': continue
            elif c == '\n':
              result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: title[1..^2]))
              lineBlock.delete(0, i)
              nextLoop = true
              break
            else:
              if isAfterBreak:
                result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: ""))
                lineBlock.delete(0, urlEndPos)
                break linkDetecting
              else:
                break linkDetecting
              
        
        if nextLoop:
          continue

        elif url == "":
          if isUrlLT:
            result.add(Block(kind: linkRef, linkLabel: label, linkUrl: "", linkTitle: ""))
            return result
          else:
            break linkDetecting

        elif url != "" and title == "":
          result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: ""))
          return result
      
        elif url != "" and title != "":
          if (title[0] == '"' and title[^1] == '"') or
             (title[0] == '\'' and title[^1] == '\'') or
             (title[0] == '(' and title[^1] == ')'):
            result.add(Block(kind: linkRef, linkLabel: label, linkUrl: url, linkTitle: title[1..^2]))
            return result
          else:
            break linkDetecting

        else:
          if lineBlock.startsWith(reLinkRef):
            continue
          else: break


  if lineBlock == "":
    return result
  else:
    result.add(Block(kind: leafBlock, leafType: paragraph, raw: lineBlock))
    return result