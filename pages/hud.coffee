findMode = null

# Set the input element's text, and move the cursor to the end.
setTextInInputElement = (inputElement, text) ->
  inputElement.textContent = text
  # Move the cursor to the end.  Based on one of the solutions here:
  # http://stackoverflow.com/questions/1125292/how-to-move-cursor-to-end-of-contenteditable-entity
  range = document.createRange()
  range.selectNodeContents inputElement
  range.collapse false
  selection = window.getSelection()
  selection.removeAllRanges()
  selection.addRange range

document.addEventListener "keydown", (event) ->
  inputElement = document.getElementById "hud-find-input"
  return unless inputElement? # Don't do anything if we're not in find mode.

  if (event.keyCode in [keyCodes.backspace, keyCodes.deleteKey] and inputElement.textContent.length == 0) or
     event.keyCode == keyCodes.enter or KeyboardUtils.isEscape event

    UIComponentServer.postMessage
      name: "hideFindMode"
      exitEventIsEnter: event.keyCode == keyCodes.enter
      exitEventIsEscape: KeyboardUtils.isEscape event

  else if event.keyCode == keyCodes.upArrow
    if rawQuery = FindModeHistory.getQuery findMode.historyIndex + 1
      findMode.historyIndex += 1
      findMode.partialQuery = findMode.rawQuery if findMode.historyIndex == 0
      setTextInInputElement inputElement, rawQuery
      findMode.executeQuery()
  else if event.keyCode == keyCodes.downArrow
    findMode.historyIndex = Math.max -1, findMode.historyIndex - 1
    rawQuery = if 0 <= findMode.historyIndex then FindModeHistory.getQuery findMode.historyIndex else findMode.partialQuery
    setTextInInputElement inputElement, rawQuery
    findMode.executeQuery()
  else
    return

  DomUtils.suppressEvent event
  false

handlers =
  show: (data) ->
    document.getElementById("hud").innerText = data.text
    document.getElementById("hud").classList.add "vimiumUIComponentVisible"
    document.getElementById("hud").classList.remove "vimiumUIComponentHidden"
  hidden: ->
    # We get a flicker when the HUD later becomes visible again (with new text) unless we reset its contents
    # here.
    document.getElementById("hud").innerText = ""
    document.getElementById("hud").classList.add "vimiumUIComponentHidden"
    document.getElementById("hud").classList.remove "vimiumUIComponentVisible"

  showFindMode: (data) ->
    hud = document.getElementById "hud"
    hud.innerText = "/\u200A" # \u200A is a "hair space", to leave enough space before the caret/first char.

    inputElement = document.createElement "span"
    inputElement.contentEditable = "plaintext-only"
    inputElement.id = "hud-find-input"
    hud.appendChild inputElement

    inputElement.addEventListener "input", executeQuery = (event) ->
      # Replace \u00A0 (&nbsp;) with a normal space.
      findMode.rawQuery = inputElement.textContent.replace "\u00A0", " "
      UIComponentServer.postMessage {name: "search", query: findMode.rawQuery}

    countElement = document.createElement "span"
    countElement.id = "hud-match-count"
    countElement.style.float = "right"
    hud.appendChild countElement
    inputElement.focus()

    findMode =
      historyIndex: -1
      partialQuery: ""
      rawQuery: ""
      executeQuery: executeQuery

  updateMatchesCount: ({matchCount, showMatchText}) ->
    countElement = document.getElementById "hud-match-count"
    return unless countElement? # Don't do anything if we're not in find mode.

    countText = if matchCount > 0
      " (#{matchCount} Match#{if matchCount == 1 then "" else "es"})"
    else
      " (No matches)"
    countElement.textContent = if showMatchText then countText else ""

UIComponentServer.registerHandler ({data}) -> handlers[data.name ? data]? data
FindModeHistory.init()
