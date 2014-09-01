class this.MMD
  constructor: (canvas, @width, @height) ->
    @gl = canvas.getContext('webgl') or canvas.getContext('experimental-webgl')
    # @gl = WebGLDebugUtils.makeDebugContext(canvas.getContext("webgl") or canvas.getContext('experimental-webgl'))
    if not @gl
      alert('WebGL not supported in your browser')
      throw 'WebGL not supported'
    @model_count = 0
    @models = {}
    @renderers = {}
    @initMatrices()

    # @pmdProgram = @initShaders(MMD.PMDVertexShaderSource, MMD.PMDFragmentShaderSource)
    # @pmxProgram = @initShaders(MMD.PMXVertexShaderSource, MMD.PMXFragmentShaderSource)
    @initParameters()
    # maxVSattribs = @gl.getParameter(@gl.MAX_VERTEX_ATTRIBS)
    # console.log maxVSattribs

  # set up basic matrices
  initMatrices: ->
    @mvMatrixStack = []
    @pMatrix = mat4.createIdentity()
    @mvMatrix = mat4.createIdentity()

  mvPushMatrix: ->
    copy = mat4.create()
    mat4.set(@mvMatrix, copy)
    @mvMatrixStack.push(copy)

  mvPopMatrix: ->
    if @mvMatrixStack.length is 0
        throw "Invalid popMatrix!"
    @mvMatrix = @mvMatrixStack.pop()

  initShaders: (vShaderSource, fShaderSource) ->
    vshader = @gl.createShader(@gl.VERTEX_SHADER)
    @gl.shaderSource(vshader, vShaderSource)
    @gl.compileShader(vshader)
    if not @gl.getShaderParameter(vshader, @gl.COMPILE_STATUS)
      alert('Vertex shader compilation error')
      throw @gl.getShaderInfoLog(vshader)

    fshader = @gl.createShader(@gl.FRAGMENT_SHADER)
    @gl.shaderSource(fshader, fShaderSource)
    @gl.compileShader(fshader)
    if not @gl.getShaderParameter(fshader, @gl.COMPILE_STATUS)
      alert('Fragment shader compilation error')
      throw @gl.getShaderInfoLog(fshader)

    program = @gl.createProgram()
    @gl.attachShader(program, vshader)
    @gl.attachShader(program, fshader)

    @gl.linkProgram(program)
    if not @gl.getProgramParameter(program, @gl.LINK_STATUS)
      alert('Shader linking error')
      throw @gl.getProgramInfoLog(program)

    @gl.useProgram(program)

    attributes = []
    uniforms = []
    for src in [vShaderSource, fShaderSource]
      for line in src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '').split(';')
        type = line.match(/^\s*(uniform|attribute)\s+/)?[1]
        continue if not type
        name = line.match(/(\w+)(\[\d+\])?\s*$/)[1]
        attributes.push(name) if type is 'attribute' and name not in attributes
        uniforms.push(name) if type is 'uniform' and name not in uniforms
        
    console.log "==============="
    for name in attributes
      program[name] = @gl.getAttribLocation(program, name)
      @gl.enableVertexAttribArray(program[name])
      console.log "#{name}: #{program[name]} => #{@gl.getError()}"

    for name in uniforms
      program[name] = @gl.getUniformLocation(program, name)

    return program

  addModel: (name, model) ->
    @models[name] = model
    @model_count++
    return

  getModelRenderer: (name) ->
    @renderers[name]

  load: (callback) ->
    that = this
    for name, model of @models
      model.load ->
        if --that.model_count <= 0
          # if all finishes, iterate and add all the models to the scene
          for k, m of that.models
            that.renderers[k] = new MMD.Renderer(that, m)
          callback()
    return

  start: ->
    @gl.clearColor(1, 1, 1, 1)
    @gl.clearDepth(1)
    @gl.enable(@gl.DEPTH_TEST)

    @redraw = true

    @shadowMap = new MMD.ShadowMap(this) if @drawSelfShadow
    @motionManager = new MMD.MotionManager

    count = 0
    t0 = before = Date.now()
    interval = 1000 / @fps

    step = =>
      @move()
      # @computeMatrices()
      @render()

      now = Date.now()

      if ++count % @fps == 0
        @realFps = @fps / (now - before) * 1000
        before = now

      setTimeout(step, (t0 + count * interval) - now) # target_time - now

    step()
    return

  move: ->
    for key, renderer of @renderers
      if renderer.playing
        renderer.move()
    return

  computeMatrices: (modelMatrix) ->
    # @modelMatrix = mat4.createIdentity() # model aligned with the world for now

    @cameraPosition = vec3.create([0, 0, @distance]) # camera position in world space
    vec3.rotateX(@cameraPosition, @rotx)
    vec3.rotateY(@cameraPosition, @roty)
    vec3.moveBy(@cameraPosition, @center)

    up = [0, 1, 0]
    vec3.rotateX(up, @rotx)
    vec3.rotateY(up, @roty)

    @viewMatrix = mat4.lookAt(@cameraPosition, @center, up)

    @mvMatrix = mat4.createMultiply(@viewMatrix, modelMatrix)

    @pMatrix = mat4.perspective(@fovy, @width / @height, 0.1, 1000.0)

    # normal matrix; inverse transpose of mvMatrix
    # model -> view space; only applied to directional vectors (not points)
    @nMatrix = mat4.inverseTranspose(@mvMatrix, mat4.create())
    return

  render: ->
    return if not @redraw and not @playing
    @redraw = false

    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @gl.viewport(0, 0, @width, @height)
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)

    for key, renderer of @renderers
      @mvPushMatrix()
      @computeMatrices(renderer.modelMatrix)
      renderer.render()
      @mvPopMatrix()

    # # reset
    # @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    # @gl.viewport(0, 0, @width, @height) # not needed on Windows Chrome but necessary on Mac Chrome
    #
    # @computeMatrices(mat4.createIdentity())
    # @setPMDUniforms()
    # @renderAxes()

    @gl.flush()
    return

  setPMDUniforms: ->
    if not @pmdProgram?
      @pmdProgram = @initShaders(MMD.PMDVertexShaderSource, MMD.PMDFragmentShaderSource)
    @gl.useProgram(@pmdProgram)
    @gl.uniform1f(@pmdProgram.uEdgeThickness, @edgeThickness)
    @gl.uniform3fv(@pmdProgram.uEdgeColor, @edgeColor)
    @gl.uniformMatrix4fv(@pmdProgram.uMVMatrix, false, @mvMatrix)
    @gl.uniformMatrix4fv(@pmdProgram.uPMatrix, false, @pMatrix)
    @gl.uniformMatrix4fv(@pmdProgram.uNMatrix, false, @nMatrix)

    # direction of light source defined in world space, then transformed to view space
    lightDirection = vec3.createNormalize(@lightDirection) # world space
    mat4.multiplyVec3(@nMatrix, lightDirection) # view space
    @gl.uniform3fv(@pmdProgram.uLightDirection, lightDirection)

    @gl.uniform3fv(@pmdProgram.uLightColor, @lightColor)
    return

  setPMXUniforms: ->
    if not @pmxProgram?
      @pmxProgram = @initShaders(MMD.PMXVertexShaderSource, MMD.PMXFragmentShaderSource)
    @gl.useProgram(@pmxProgram)
    # @gl.uniform1f(@pmxProgram.uEdgeThickness, @edgeThickness)
    @gl.uniformMatrix4fv(@pmxProgram.uMVMatrix, false, @mvMatrix)
    @gl.uniformMatrix4fv(@pmxProgram.uPMatrix, false, @pMatrix)
    @gl.uniformMatrix4fv(@pmxProgram.uNMatrix, false, @nMatrix)

    # direction of light source defined in world space, then transformed to view space
    lightDirection = vec3.createNormalize(@lightDirection) # world space
    mat4.multiplyVec3(@nMatrix, lightDirection) # view space
    @gl.uniform3fv(@pmxProgram.uLightDirection, lightDirection)

    @gl.uniform3fv(@pmxProgram.uLightColor, @lightColor)
    return

  # renderAxes: ->
  #
  #   axisBuffer = @gl.createBuffer()
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, axisBuffer)
  #   @gl.vertexAttribPointer(@pmdProgram.aMultiPurposeVector, 3, @gl.FLOAT, false, 0, 0)
  #   if @drawAxes
  #     @gl.uniform1i(@pmdProgram.uAxis, true)
  #
  #     for i in [0...3]
  #       axis = [0, 0, 0, 0, 0, 0]
  #       axis[i] = 65 # from [65, 0, 0] to [0, 0, 0] etc.
  #       color = [0, 0, 0]
  #       color[i] = 1
  #       @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(axis), @gl.STATIC_DRAW)
  #       @gl.uniform3fv(@pmdProgram.uAxisColor, color)
  #       @gl.drawArrays(@gl.LINES, 0, 2)
  #
  #     axis = [
  #       -50, 0, 0, 0, 0, 0 # negative x-axis (from [-50, 0, 0] to origin)
  #       0, 0, -50, 0, 0, 0 # negative z-axis (from [0, 0, -50] to origin)
  #     ]
  #     for i in [-50..50] by 5
  #       if i != 0
  #         axis.push(
  #           i,   0, -50,
  #           i,   0, 50, # one line parallel to the x-axis
  #           -50, 0, i,
  #           50,  0, i   # one line parallel to the z-axis
  #         )
  #     color = [0.7, 0.7, 0.7]
  #     @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(axis), @gl.STATIC_DRAW)
  #     @gl.uniform3fv(@pmdProgram.uAxisColor, color)
  #     @gl.drawArrays(@gl.LINES, 0, 84)
  #
  #     @gl.uniform1i(@pmdProgram.uAxis, false)
  #
  #   # draw center point
  #   if @drawCenterPoint
  #     @gl.uniform1i(@pmdProgram.uCenterPoint, true)
  #     @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(@center), @gl.STATIC_DRAW)
  #     @gl.drawArrays(@gl.POINTS, 0, 1)
  #     @gl.uniform1i(@pmdProgram.uCenterPoint, false)
  #
  #   @gl.deleteBuffer(axisBuffer)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
  #   return

  registerKeyListener: (element) ->
    element.addEventListener('keydown', (e) =>
      switch e.keyCode + e.shiftKey * 1000 + e.ctrlKey * 10000 + e.altKey * 100000
        when 37 then @roty += Math.PI / 48 # left
        when 39 then @roty -= Math.PI / 48 # right
        when 38 then @rotx += Math.PI / 48 # up
        when 40 then @rotx -= Math.PI / 48 # down
        when 33 then @distance -= 3 * @distance / @DIST # pageup
        when 34 then @distance += 3 * @distance / @DIST # pagedown
        when 36 # home
          @rotx = @roty = 0
          @center = [0, 10, 0]
          @distance = @DIST
        when 1037 # shift + left
          vec3.multiplyMat4(@center, @mvMatrix)
          @center[0] -= @distance / @DIST
          vec3.multiplyMat4(@center, mat4.createInverse(@mvMatrix))
        when 1039 # shift + right
          vec3.multiplyMat4(@center, @mvMatrix)
          @center[0] += @distance / @DIST
          vec3.multiplyMat4(@center, mat4.createInverse(@mvMatrix))
        when 1038 # shift +  up
          vec3.multiplyMat4(@center, @mvMatrix)
          @center[1] += @distance / @DIST
          vec3.multiplyMat4(@center, mat4.createInverse(@mvMatrix))
        when 1040 # shift + down
          vec3.multiplyMat4(@center, @mvMatrix)
          @center[1] -= @distance / @DIST
          vec3.multiplyMat4(@center, mat4.createInverse(@mvMatrix))
        when 32 # space
          if @playing
            @pause()
          else
            @play()
        else return

      e.preventDefault()
      @redraw = true
    , false)
    return

  registerMouseListener: (element) ->
    @registerDragListener(element)
    @registerWheelListener(element)
    return

  registerDragListener: (element) ->
    element.addEventListener('mousedown', (e) =>
      return if e.button != 0
      modifier = e.shiftKey * 1000 + e.ctrlKey * 10000 + e.altKey * 100000
      return if modifier != 0 and modifier != 1000
      ox = e.clientX; oy = e.clientY

      move = (dx, dy, modi) =>
        if modi == 0
          @roty -= dx / 100
          @rotx -= dy / 100
          @redraw = true
        else if modi == 1000
          vec3.multiplyMat4(@center, @mvMatrix)
          @center[0] -= dx / 30 * @distance / @DIST
          @center[1] += dy / 30 * @distance / @DIST
          vec3.multiplyMat4(@center, mat4.createInverse(@mvMatrix))
          @redraw = true

      onmouseup = (e) =>
        return if e.button != 0
        modi = e.shiftKey * 1000 + e.ctrlKey * 10000 + e.altKey * 100000
        move(e.clientX - ox, e.clientY - oy, modi)
        element.removeEventListener('mouseup', onmouseup, false)
        element.removeEventListener('mousemove', onmousemove, false)
        e.preventDefault()

      onmousemove = (e) =>
        return if e.button != 0
        modi = e.shiftKey * 1000 + e.ctrlKey * 10000 + e.altKey * 100000
        x = e.clientX; y = e.clientY
        move(x - ox, y - oy, modi)
        ox = x; oy = y
        e.preventDefault()

      element.addEventListener('mouseup', onmouseup, false)
      element.addEventListener('mousemove', onmousemove, false)
    , false)
    return

  registerWheelListener: (element) ->
    onwheel = (e) =>
      delta = e.detail || e.wheelDelta / (-40) # positive: wheel down
      @distance += delta * @distance / @DIST
      @redraw = true
      e.preventDefault()

    if 'onmousewheel' of window
      element.addEventListener('mousewheel', onwheel, false)
    else
      element.addEventListener('DOMMouseScroll', onwheel, false)

    return

  initParameters: ->
    # camera/view settings
    @ignoreCameraMotion = false
    @rotx = @roty = 0
    @distance = @DIST = 35
    @center = [0, 10, 0]
    @fovy = 40

    # edge
    @drawEdge = true
    @edgeThickness = 0.004
    @edgeColor = [0, 0, 0]

    # light
    @lightDirection = [0.5, 1.0, 0.5]
    @lightDistance = 8875
    @lightColor = [0.6, 0.6, 0.6]

    # misc
    @drawSelfShadow = true
    @drawAxes = true
    @drawCenterPoint = false

    @fps = 30 # redraw every 1000/30 msec
    @realFps = @fps
    @playing = false
    @frame = -1
    return

  # addCameraLightMotion: (motion, merge_flag, frame_offset) ->
  #   @motionManager.addCameraLightMotion(motion, merge_flag, frame_offset)
  #   return

  play: ->
    @playing = true
    return

  pause: ->
    @playing = false
    return

  rewind: ->
    @setFrameNumber(-1)
    return

  setFrameNumber: (num) ->
    @frame = num
    return

