fs     = require 'fs'
{exec} = require 'child_process'
util   = require 'util'

prodSrcCoffeeDir     = 'src'
# testSrcCoffeeDir     = 'test/src/coffee-script'

prodTargetJsDir      = './'
# prodTargetJsDir      = 'dist/js'
# testTargetJsDir      = 'test/src/js'

prodTargetFileName   = 'MMD-lib'
prodTargetCoffeeFile = "#{prodSrcCoffeeDir}/#{prodTargetFileName}.coffee"
prodTargetJsFile     = "#{prodTargetJsDir}/#{prodTargetFileName}.js"

prodCoffeeOpts = "--bare --output #{prodTargetJsDir} --compile #{prodTargetCoffeeFile}"
# testCoffeeOpts = "--output #{testTargetJsDir}"

prodCoffeeFiles = [
    'MMD'
    'MMD.Model'
    'MMD.Motion'
    'MMD.MotionManager'
    'MMD.PMDModel'
    'MMD.PMDRenderer'
    'MMD.PMXModel'
    'MMD.PMXRenderer'
    'MMD.PMDVertexShaderSource'
    'MMD.PMDFragmentShaderSource'
    'MMD.PMXVertexShaderSource'
    'MMD.PMXFragmentShaderSource'
    'MMD.ShadowMap'
    'MMD.TextureManager'
]

task 'build', 'Build a single JavaScript file from prod files', ->
    util.log "Building #{prodTargetJsFile}"
    appContents = new Array remaining = prodCoffeeFiles.length
    util.log "Appending #{prodCoffeeFiles.length} files to #{prodTargetCoffeeFile}"

    for file, index in prodCoffeeFiles then do (file, index) ->
        fs.readFile "#{prodSrcCoffeeDir}/#{file}.coffee"
                  , 'utf8'
                  , (err, fileContents) ->
            util.log err if err

            appContents[index] = fileContents
            util.log "[#{index + 1}] #{file}.coffee"
            process() if --remaining is 0

    process = ->
        fs.writeFile prodTargetCoffeeFile
                   , appContents.join('\n\n')
                   , 'utf8'
                   , (err) ->
            util.log err if err

            exec "coffee #{prodCoffeeOpts}", (err, stdout, stderr) ->
                util.log err if err
                message = "Compiled #{prodTargetJsFile}"
                util.log message
                fs.unlink prodTargetCoffeeFile, (err) -> util.log err if err

task 'watch', 'Watch prod source files and build changes', ->
    util.log "Watching for changes in #{prodSrcCoffeeDir}"

    for file in prodCoffeeFiles then do (file) ->
        fs.watchFile "#{prodSrcCoffeeDir}/#{file}.coffee", (curr, prev) ->
            if +curr.mtime isnt +prev.mtime
                util.log "Saw change in #{prodSrcCoffeeDir}/#{file}.coffee"
                invoke 'build'
