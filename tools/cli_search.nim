# SPDX-License-Identifier: AGPL-3.0-only
import os, strutils, asyncdispatch, strformat

# Add the src directory to the import path
when defined(windows):
  import winim/lean
  const lib = "nitter_lib.dll"
  proc nimLoadLibrary(path: string): LibHandle {.cdecl, importc, dynlib.}
  proc nimUnloadLibrary(lib: LibHandle) {.cdecl, importc, dynlib.}
  proc nimRegisterPath(path: cstring, isUserPath: bool) {.cdecl, importc, dynlib.}
  var handle = nimLoadLibrary(lib)
  nimRegisterPath(absolutePath(r"../src", getCurrentDir()).cstring, true)
else:
  import posix
  const nimcache = getEnv("NIMCACHE", "nimcache")
  let lib = "nitter_lib.so"
  let handle = dlopen(lib, RTLD_LAZY)
  type NimRegisterPath = proc(path: cstring, isUserPath: bool) {.cdecl.}
  let nimRegisterPath = cast[NimRegisterPath](dlsym(handle, "nimRegisterPath"))
  nimRegisterPath(absolutePath(r"../src", getCurrentDir()).cstring, true)

import api, query, types, http_pool

proc search() {.async.} =
  if paramCount() == 0:
    echo "Usage: nim r tools/cli_search.nim <search term>"
    return

  let searchTerm = commandLineParams().join(" ")
  echo &"Searching for: {searchTerm}"

  # Create a query object
  let query = Query(kind: tweets, text: searchTerm)

  # Perform the search
  try:
    let timeline = await getGraphTweetSearch(query)

    if timeline.content.len > 0:
      echo &"\n--- Found {timeline.content.len} tweets ---\n"
      for tweet in timeline.content:
        echo &"User: @{tweet.user.username}"
        echo &"Time: {tweet.time}"
        echo &"Text: {tweet.text.replace("\n", "\n      ")} " # Indent multiline tweets
        echo "---"
    else:
      echo "No results found."
  except Exception as e:
    echo &"An error occurred: {e.name} - {e.msg}"

waitFor search()
