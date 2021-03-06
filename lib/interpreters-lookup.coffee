fs = require 'fs'
os = require 'os'
path = require 'path'
log = require './log'

module.exports =
  pythonExecutableRe: ->
    if /^win/.test process.platform
      return /^python(\d+(.\d+)?)?\.exe$/
    else
      return /^python(\d+(.\d+)?)?$/

  possibleGlobalPythonPaths: ->
    if /^win/.test process.platform
      return [
        'C:\\Python2.7'
        'C:\\Python3.4'
        'C:\\Python3.5'
        'C:\\Program Files (x86)\\Python 2.7'
        'C:\\Program Files (x86)\\Python 3.4'
        'C:\\Program Files (x86)\\Python 3.5'
        'C:\\Program Files (x64)\\Python 2.7'
        'C:\\Program Files (x64)\\Python 3.4'
        'C:\\Program Files (x64)\\Python 3.5'
        'C:\\Program Files\\Python 2.7'
        'C:\\Program Files\\Python 3.4'
        'C:\\Program Files\\Python 3.5'
        "#{os.homedir()}\\AppData\\Local\\Programs\\Python\\Python35-32"
      ]
    else
      return ['/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin']

  readDir: (dirPath) ->
    try
      return fs.readdirSync dirPath
    catch
      return []

  isBinary: (filePath) ->
    try
      fs.accessSync filePath, fs.X_OK
      return true
    catch
      return false

  lookupInterpreters: (dirPath) ->
    interpreters = new Set()
    files = @readDir(dirPath)
    matches = (f for f in files when @pythonExecutableRe().test(f))
    for fileName in matches
      potentialInterpreter = path.join(dirPath, fileName)
      if @isBinary(potentialInterpreter)
        interpreters.add(potentialInterpreter)
    return interpreters

  getInterpreter: ->
    userDefinedPythonPaths = []
    for p in atom.config.get('autocomplete-python.pythonPaths').split(';')
      for project in atom.project.getPaths()
        modified = p.replace(/\$PROJECT/i, project)
        if modified not in userDefinedPythonPaths
          userDefinedPythonPaths.push(modified)
    interpreters = new Set(p for p in userDefinedPythonPaths when @isBinary(p))
    if interpreters.size > 0
      log.debug 'User defined interpreters found', interpreters
      return interpreters.keys().next().value

    log.debug 'No user defined interpreter found, trying automatic lookup'
    interpreters = new Set()

    for project in atom.project.getPaths()
      for f in @readDir(project)
        @lookupInterpreters(path.join(project, f, 'bin')).forEach (i) ->
          interpreters.add(i)
    log.debug 'Project level interpreters found', interpreters
    envPath = (process.env.PATH or '').split path.delimiter
    envPath = new Set(envPath.concat(@possibleGlobalPythonPaths()))
    envPath.forEach (potentialPath) =>
      @lookupInterpreters(potentialPath).forEach (i) ->
        interpreters.add(i)
    log.debug 'Total automatically found interpreters', interpreters

    if interpreters.size > 0
      return interpreters.keys().next().value
