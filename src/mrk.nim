import strutils, json, re
# import nimprof

type
  Blocktype = enum
    undefinedblock,
    paragraph,
    header1,
    header2,
    header3,
    header4,
    header5,
    header6,
    themanticbreak,
    blockquote,
    unorderedlist,
    orderedlist,
    codeblock,
    horizontalrule

  Inlinetype = enum
    undefinedinline,
    linebreak,
    softbreak,
    link,
    em,
    strong,
    code,
    image,
    text

  ToggleContainer = ref object
    toggleBlockquote: bool
    toggleCodeBlock: bool
    toggleBulletListDashSpace: bool
    toggleBulletListPlusSpace: bool
    toggleBulletListAsteSpace: bool
    toggleBulletListDashPare: bool
    toggleBulletListPlusPare: bool
    toggleBulletListAstePare: bool
    toggleOrderedListSpace: bool
    toggleOrderedListPare: bool

type 
  Block = ref object
    kind: Blocktype
    values: Inline
 
  Inline = ref object
    kind: Inlinetype
    value: seq[string]

  Root = ref object
    kind: string
    children: seq[Block]

let
  reThematicBreak = re"^(| |  |   )(\*{3,}|-{3,}|_{3,})"
  reSetextHeader1 = re"^(| |  |   )(=+)"
  reSetextHeader2 = re"^(| |  |   )(--+)"
  reAtxHeader = re"^(| |  |   )(#|##|###|####|#####|######) "
  reBlockquote = re"^(| |  |   )>(| )"
  reBulletListDashSpace = re"^(| |  |   )- "
  reBulletListPlusSpace = re"^(| |  |   )\+ "
  reBulletListAsteSpace = re"^(| |  |   )\* "
  reBulletListDashPare = re"^(| |  |   )-\)"
  reBulletListPlusPare = re"^(| |  |   )\+\)"
  reBulletListAstePare = re"^(| |  |   )\*\)"
  reOrderedListSpaceStart = re"^(| |  |   )1\. "
  reOrderedListPareStart = re"^(| |  |   )1\)"
  reOrderedListSpace = re"^(| |  |   )(2|3|4|5|6|7|8|9)\. "
  reOrderedListPare = re"^(| |  |   )(2|3|4|5|6|7|8|9)\)"
  reCodeBlock = re"^(| |  |   )(```|~~~)"
  reParagraph = re"^(| |  |   )[^\*-_=+#>123456789(```)(~~~)]"

proc isSetextHeader1(line: string): bool =
  match(line, reSetextHeader1)
proc isSetextHeader2(line: string): bool =
  match(line, reSetextHeader2)

proc isThemanticBreak(line: string): bool =
  match(line, reThematicBreak)

proc isAtxHeader(line: string): bool =
  match(line, reAtxHeader)

proc isBlockquote(line: string): bool =
  match(line, reBlockquote)

proc isCodeFence(line: string): bool =
  match(line, reCodeBlock)

proc isParagraph(line: string): bool =
  match(line, reParagraph)

proc isBulletListDashSpace(line: string): bool =
  match(line, reBulletListDashSpace)
proc isBulletListPlusSpace(line: string): bool =
  match(line, reBulletListPlusSpace)
proc isBulletListAsteSpace(line: string): bool =
  match(line, reBulletListAsteSpace)
proc isBulletListDashPare(line: string): bool =
  match(line, reBulletListDashPare)
proc isBulletListPlusPare(line: string): bool =
  match(line, reBulletListDashPare)
proc isBulletListAstePare(line: string): bool =
  match(line, reBulletListDashPare)
proc isOrderdListSpaceStart(line: string): bool =
  match(line, reOrderedListSpaceStart)
proc isOrderdListPareStart(line: string): bool =
  match(line, reOrderedListPareStart)
proc isOrderdListSpace(line: string): bool =
  match(line, reOrderedListSpace)
proc isOrderdListPare(line: string): bool =
  match(line, reOrderedListPare)

proc newToggle(): ToggleContainer =
  ToggleContainer(
    toggleBlockquote: false,
    toggleCodeBlock: false,
    toggleBulletListDashSpace: false,
    toggleBulletListPlusSpace: false,
    toggleBulletListAsteSpace: false,
    toggleBulletListDashPare: false,
    toggleBulletListPlusPare: false,
    toggleBulletListAstePare: false,
    toggleOrderedListSpace: false,
    toggleOrderedListPare: false
  )

proc parseHeader(line: string): Block =
  case line.splitWhitespace[0]:
    of "#":
      let str = line.replace(reAtxHeader)
      return Block(kind: header1, values: Inline(kind: text, value: @[str]))
    of "##":
      let str = line.replace(reAtxHeader)
      return Block(kind: header2, values: Inline(kind: text, value: @[str]))
    of "###":
      let str = line.replace(reAtxHeader)
      return Block(kind: header3, values: Inline(kind: text, value: @[str]))
    of "####":
      let str = line.replace(reAtxHeader)
      return Block(kind: header4, values: Inline(kind: text, value: @[str]))
    of "#####":
      let str = line.replace(reAtxHeader)
      return Block(kind: header5, values: Inline(kind: text, value: @[str]))
    of "######":
      let str = line.replace(reAtxHeader)
      return Block(kind: header6, values: Inline(kind: text, value: @[str]))

proc parseBlockquote(line: string): Block =
  let str = line.replace(reBlockquote)
  return Block(kind: blockquote, values: Inline(kind: text, value: @[str]))

proc parseParagraph(line: string): Block =
  Block(kind: paragraph, values: Inline(kind: text, value: @[line]))

proc parseLine(s: string): seq[Block] =
  var mdast: seq[Block]
  var lineBlock: string
  var blockquoteSeq: seq[string]
  var unorderedListSeq: seq[string]
  var orderedListSeq: seq[string]
  var container = newToggle()

  for line in s.splitLines:

    block blockquotes:
      if container.toggleBlockquote:
        if not (line.isParagraph or line.isBlockquote):
          mdast.add(Block(kind: blockquote, values: Inline(kind: text, value: blockquoteSeq)))
          blockquoteSeq = @[]
          container.toggleBlockquote = false
          break blockquotes
        else:
          blockquoteSeq.add(line)

    block bulletListDashSpace:
      if container.toggleBulletListDashSpace:
        if line.isBulletListDashSpace:
          unorderedListSeq.add(line.replace(reBulletListDashSpace))
          continue
        else:
          mdast.add(Block(kind: unorderedlist, values: Inline(kind: text, value: unorderedListSeq)))
          unorderedListSeq = @[]
          container.toggleBulletListDashSpace = false
          break bulletListDashSpace

    block orderedListDashSpace:
      if container.toggleOrderedListSpace:
        if line.isOrderdListSpace:
          orderedListSeq.add(line.replace(reOrderedListSpace))
          continue
        else:
          mdast.add(Block(kind: orderedlist, values: Inline(kind: text, value: orderedListSeq)))
          orderedListSeq = @[]
          container.toggleOrderedListSpace = false
          break orderedListDashSpace

    if container.toggleCodeBlock:
      if not line.isCodeFence:
        lineBlock.add(line & "<br />")
      else:
        mdast.add(Block(kind: codeblock, values: Inline(kind: code, value: @[lineBlock])))
        lineblock = ""
        container.toggleCodeBlock = false

    elif line.isBlockquote:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      blockquoteSeq.add(line.replace(reBlockquote))
      container.toggleBlockquote = true
    
    elif line.isBulletListDashSpace:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListDashSpace))
      container.toggleBulletListDashSpace = true
    elif line.isBulletListPlusSpace:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListPlusSpace))
      container.toggleBulletListPlusSpace = true
    elif line.isBulletListAsteSpace:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListAsteSpace))
      container.toggleBulletListAsteSpace = true
    
    elif line.isBulletListDashPare:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListDashPare))
      container.toggleBulletListDashPare = true
    elif line.isBulletListPlusPare:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListPlusPare))
      container.toggleBulletListPlusPare = true
    elif line.isBulletListAstePare:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      unorderedListSeq.add(line.replace(reBulletListPlusPare))
      container.toggleBulletListAstePare = true
    
    elif line.isOrderdListSpaceStart:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      orderedListSeq.add(line.replace(reOrderedListSpaceStart))
      container.toggleOrderedListSpace = true

    elif line.isOrderdListPareStart:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      orderedListSeq.add(line.replace(reOrderedListPareStart))
      container.toggleOrderedListPare = true

    elif line.isCodeFence:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      container.toggleCodeBlock = true
    
    elif line.isAtxHeader:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
      mdast.add(parseHeader(line))
      lineBlock = ""
    
    elif line.isSetextHeader1:
      if lineBlock != "":
        mdast.add(Block(kind: header1, values: Inline(kind: text, value: @[lineBlock])))
        lineBlock = ""
      else:
        lineBlock.add(line)
    
    elif line.isSetextHeader2:
      if lineBlock != "":
        mdast.add(Block(kind: header2, values: Inline(kind: text, value: @[lineBlock])))
        lineBlock = ""
      else:
        mdast.add(Block(kind: themanticbreak, values: Inline()))
    
    elif line.isThemanticBreak:
      if lineBlock != "":
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""
      mdast.add(Block(kind: themanticbreak, values: Inline()))

    elif line.isEmptyOrWhitespace:
      if not lineBlock.isEmptyOrWhitespace:
        mdast.add(parseParagraph(lineBlock))
        lineBlock = ""

    else:
      lineBlock.add(line)

  if lineBlock != "":
    mdast.add(parseParagraph(lineBlock))

  return mdast

when isMainModule:
  var s = readFile("testfiles/1.md").replace("  \n", "<br />")
  var root = Root(kind: "root", children: @[])
  root.children = parseLine(s)
  echo pretty(%root)