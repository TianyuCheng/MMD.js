class this.MMD
  constructor: (canvas, @width, @height) ->
    @gl = canvas.getContext('webgl') or canvas.getContext('experimental-webgl')
    if not @gl
      alert('WebGL not supported in your browser')
      throw 'WebGL not supported'
    @model_count = 0
    @models = {}
    @renderers = {}

  initShaders: ->
    vshader = @gl.createShader(@gl.VERTEX_SHADER)
    @gl.shaderSource(vshader, MMD.VertexShaderSource)
    @gl.compileShader(vshader)
    if not @gl.getShaderParameter(vshader, @gl.COMPILE_STATUS)
      alert('Vertex shader compilation error')
      throw @gl.getShaderInfoLog(vshader)

    fshader = @gl.createShader(@gl.FRAGMENT_SHADER)
    @gl.shaderSource(fshader, MMD.FragmentShaderSource)
    @gl.compileShader(fshader)
    if not @gl.getShaderParameter(fshader, @gl.COMPILE_STATUS)
      alert('Fragment shader compilation error')
      throw @gl.getShaderInfoLog(fshader)

    @program = @gl.createProgram()
    @gl.attachShader(@program, vshader)
    @gl.attachShader(@program, fshader)

    @gl.linkProgram(@program)
    if not @gl.getProgramParameter(@program, @gl.LINK_STATUS)
      alert('Shader linking error')
      throw @gl.getProgramInfoLog(@program)

    @gl.useProgram(@program)

    attributes = []
    uniforms = []
    for src in [MMD.VertexShaderSource, MMD.FragmentShaderSource]
      for line in src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '').split(';')
        type = line.match(/^\s*(uniform|attribute)\s+/)?[1]
        continue if not type
        name = line.match(/(\w+)(\[\d+\])?\s*$/)[1]
        attributes.push(name) if type is 'attribute' and name not in attributes
        uniforms.push(name) if type is 'uniform' and name not in uniforms

    for name in attributes
      @program[name] = @gl.getAttribLocation(@program, name)
      @gl.enableVertexAttribArray(@program[name])

    for name in uniforms
      @program[name] = @gl.getUniformLocation(@program, name)

    return

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
        that.model_count--
        # if all finishes
        if that.model_count <= 0
          # iterate and add all the models to the scene
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
      @computeMatrices()
      @render()

      now = Date.now()

      if ++count % @fps == 0
        @realFps = @fps / (now - before) * 1000
        before = now

      setTimeout(step, (t0 + count * interval) - now) # target_time - now

    step()
    return

  move: ->
    if ++@frame > @motionManager.lastFrame
      @pause()
      @frame = -1
      return

    @moveCamera()
    @moveLight()

    for key, renderer of @renderers
      renderer.move()
    return

  moveCamera: ->
    camera = @motionManager.getCameraFrame(@frame)
    if camera and not @ignoreCameraMotion
      @distance = camera.distance
      @rotx = camera.rotation[0]
      @roty = camera.rotation[1]
      @center = vec3.create(camera.location)
      @fovy = camera.view_angle

    return

  moveLight: ->
    light = @motionManager.getLightFrame(@frame)
    if light
      @lightDirection = light.location
      @lightColor = light.color

    return

  # moveModel: ->
  #   model = @model
  #   {morphs, bones} = @motionManager.getModelFrame(model, @frame)
  #
  #   @moveMorphs(model, morphs)
  #   @moveBones(model, bones)
  #   return
  #
  # moveMorphs: (model, morphs) ->
  #   return if not morphs
  #   return if model.morphs.length == 0
  #
  #   for morph, j in model.morphs
  #     if j == 0
  #       base = morph
  #       continue
  #     continue if morph.name not of morphs
  #     weight = morphs[morph.name]
  #     for vert in morph.vert_data
  #       b = base.vert_data[vert.index]
  #       i = b.index
  #       model.morphVec[3 * i    ] += vert.x * weight
  #       model.morphVec[3 * i + 1] += vert.y * weight
  #       model.morphVec[3 * i + 2] += vert.z * weight
  #
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aMultiPurposeVector.buffer)
  #   @gl.bufferData(@gl.ARRAY_BUFFER, model.morphVec, @gl.STATIC_DRAW)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
  #
  #   # reset positions
  #   for b in base.vert_data
  #     i = b.index
  #     model.morphVec[3 * i    ] = 0
  #     model.morphVec[3 * i + 1] = 0
  #     model.morphVec[3 * i + 2] = 0
  #
  #   return
  #
  # moveBones: (model, bones) ->
  #   return if not bones
  #
  #   # individualBoneMotions is translation/rotation of each bone from it's original position
  #   # boneMotions is total position/rotation of each bone
  #   # boneMotions is an array like [{p, r, tainted}]
  #   # tainted flag is used to avoid re-creating vec3/quat4
  #   individualBoneMotions = []
  #   boneMotions = []
  #   originalBonePositions = []
  #   parentBones = []
  #   constrainedBones = []
  #
  #   for bone, i in model.bones
  #     individualBoneMotions[i] = bones[bone.name] ? {
  #       rotation: quat4.create([0, 0, 0, 1])
  #       location: vec3.create()
  #     }
  #     boneMotions[i] = {
  #       r: quat4.create()
  #       p: vec3.create()
  #       tainted: true
  #     }
  #     originalBonePositions[i] = bone.head_pos
  #     parentBones[i] = bone.parent_bone_index
  #     if bone.name.indexOf('\u3072\u3056') > 0 # ひざ
  #       constrainedBones[i] = true # TODO: for now it's only for knees, but extend this if I do PMX
  #
  #   getBoneMotion = (boneIndex) ->
  #     # http://d.hatena.ne.jp/edvakf/20111026/1319656727
  #     motion = boneMotions[boneIndex]
  #     return motion if motion and not motion.tainted
  #
  #     m = individualBoneMotions[boneIndex]
  #     r = quat4.set(m.rotation, motion.r)
  #     t = m.location
  #     p = vec3.set(originalBonePositions[boneIndex], motion.p)
  #
  #     if parentBones[boneIndex] == 0xFFFF # center, foot IK, etc.
  #       return boneMotions[boneIndex] = {
  #         p: vec3.add(p, t),
  #         r: r
  #         tainted: false
  #       }
  #     else
  #       parentIndex = parentBones[boneIndex]
  #       parentMotion = getBoneMotion(parentIndex)
  #       r = quat4.multiply(parentMotion.r, r, r)
  #       p = vec3.subtract(p, originalBonePositions[parentIndex])
  #       vec3.add(p, t)
  #       vec3.rotateByQuat4(p, parentMotion.r)
  #       vec3.add(p, parentMotion.p)
  #       return boneMotions[boneIndex] = {p: p, r: r, tainted: false}
  #
  #   resolveIKs = ->
  #     # this function is run only once, but to narrow the scope I'm making a function
  #     # http://d.hatena.ne.jp/edvakf/20111102/1320268602
  #
  #     # objects to be reused
  #     targetVec = vec3.create()
  #     ikboneVec = vec3.create()
  #     axis = vec3.create()
  #     tmpQ = quat4.create()
  #     tmpR = quat4.create()
  #
  #     for ik in model.iks
  #       ikbonePos = getBoneMotion(ik.bone_index).p
  #       targetIndex = ik.target_bone_index
  #       minLength = 0.1 * vec3.length(
  #         vec3.subtract(
  #           originalBonePositions[targetIndex],
  #           originalBonePositions[parentBones[targetIndex]], axis)) # temporary use of axis
  #
  #       for n in [0...ik.iterations]
  #         targetPos = getBoneMotion(targetIndex).p # this should calculate the whole chain
  #         break if minLength > vec3.length(
  #           vec3.subtract(targetPos, ikbonePos, axis)) # temporary use of axis
  #
  #         for boneIndex, i in ik.child_bones
  #           motion = getBoneMotion(boneIndex)
  #           bonePos = motion.p
  #           targetPos = getBoneMotion(targetIndex).p if i > 0
  #           targetVec = vec3.subtract(targetPos, bonePos, targetVec)
  #           targetVecLen = vec3.length(targetVec)
  #           continue if targetVecLen < minLength # targetPos == bonePos
  #           ikboneVec = vec3.subtract(ikbonePos, bonePos, ikboneVec)
  #           ikboneVecLen = vec3.length(ikboneVec)
  #           continue if ikboneVecLen < minLength # ikbonePos == bonePos
  #           axis = vec3.cross(targetVec, ikboneVec, axis)
  #           axisLen = vec3.length(axis)
  #           sinTheta = axisLen / ikboneVecLen / targetVecLen
  #           continue if sinTheta < 0.001 # ~0.05 degree
  #           maxangle = (i + 1) * ik.control_weight * 4 # angle to move in one iteration
  #           theta = Math.asin(sinTheta)
  #           theta = 3.141592653589793 - theta if vec3.dot(targetVec, ikboneVec) < 0
  #           theta = maxangle if theta > maxangle
  #           q = quat4.set(vec3.scale(axis, Math.sin(theta / 2) / axisLen), tmpQ) # q is tmpQ
  #           q[3] = Math.cos(theta / 2)
  #           parentRotation = getBoneMotion(parentBones[boneIndex]).r
  #           r = quat4.inverse(parentRotation, tmpR) # r is tmpR
  #           r = quat4.multiply(quat4.multiply(r, q), motion.r)
  #
  #           if constrainedBones[boneIndex]
  #             c = r[3] # cos(theta / 2)
  #             r = quat4.set([Math.sqrt(1 - c * c), 0, 0, c], r) # axis must be x direction
  #             quat4.inverse(boneMotions[boneIndex].r, q)
  #             quat4.multiply(r, q, q)
  #             q = quat4.multiply(parentRotation, q, q)
  #
  #           # update individualBoneMotions[boneIndex].rotation
  #           quat4.normalize(r, individualBoneMotions[boneIndex].rotation)
  #           # update boneMotions[boneIndex].r which is the same as motion.r
  #           quat4.multiply(q, motion.r, motion.r)
  #
  #           # taint for re-calculation
  #           boneMotions[ik.child_bones[j]].tainted = true for j in [0...i]
  #           boneMotions[ik.target_bone_index].tainted = true
  #
  #   resolveIKs()
  #
  #   # calculate positions/rotations of bones other than IK
  #   getBoneMotion(i) for i in [0...model.bones.length]
  #
  #   #TODO: split
  #
  #   rotations1 = model.rotations1
  #   rotations2 = model.rotations2
  #   positions1 = model.positions1
  #   positions2 = model.positions2
  #
  #   length = model.vertices.length
  #   for i in [0...length]
  #     vertex = model.vertices[i]
  #     motion1 = boneMotions[vertex.bone_num1]
  #     motion2 = boneMotions[vertex.bone_num2]
  #     rot1 = motion1.r
  #     pos1 = motion1.p
  #     rot2 = motion2.r
  #     pos2 = motion2.p
  #     rotations1[i * 4    ] = rot1[0]
  #     rotations1[i * 4 + 1] = rot1[1]
  #     rotations1[i * 4 + 2] = rot1[2]
  #     rotations1[i * 4 + 3] = rot1[3]
  #     rotations2[i * 4    ] = rot2[0]
  #     rotations2[i * 4 + 1] = rot2[1]
  #     rotations2[i * 4 + 2] = rot2[2]
  #     rotations2[i * 4 + 3] = rot2[3]
  #     positions1[i * 3    ] = pos1[0]
  #     positions1[i * 3 + 1] = pos1[1]
  #     positions1[i * 3 + 2] = pos1[2]
  #     positions2[i * 3    ] = pos2[0]
  #     positions2[i * 3 + 1] = pos2[1]
  #     positions2[i * 3 + 2] = pos2[2]
  #
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Rotation.buffer)
  #   @gl.bufferData(@gl.ARRAY_BUFFER, rotations1, @gl.STATIC_DRAW)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Rotation.buffer)
  #   @gl.bufferData(@gl.ARRAY_BUFFER, rotations2, @gl.STATIC_DRAW)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Position.buffer)
  #   @gl.bufferData(@gl.ARRAY_BUFFER, positions1, @gl.STATIC_DRAW)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Position.buffer)
  #   @gl.bufferData(@gl.ARRAY_BUFFER, positions2, @gl.STATIC_DRAW)
  #   @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
  #   return

  computeMatrices: ->
    @modelMatrix = mat4.createIdentity() # model aligned with the world for now

    @cameraPosition = vec3.create([0, 0, @distance]) # camera position in world space
    vec3.rotateX(@cameraPosition, @rotx)
    vec3.rotateY(@cameraPosition, @roty)
    vec3.moveBy(@cameraPosition, @center)

    up = [0, 1, 0]
    vec3.rotateX(up, @rotx)
    vec3.rotateY(up, @roty)

    @viewMatrix = mat4.lookAt(@cameraPosition, @center, up)

    @mvMatrix = mat4.createMultiply(@viewMatrix, @modelMatrix)

    @pMatrix = mat4.perspective(@fovy, @width / @height, 0.1, 1000.0)

    # normal matrix; inverse transpose of mvMatrix
    # model -> view space; only applied to directional vectors (not points)
    @nMatrix = mat4.inverseTranspose(@mvMatrix, mat4.create())
    return

  render: ->
    # return if not @redraw and not @playing
    # @redraw = false

    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @gl.viewport(0, 0, @width, @height)
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)

    for key, renderer of @renderers
      renderer.render()

    @setUniforms()

    # reset
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @gl.viewport(0, 0, @width, @height) # not needed on Windows Chrome but necessary on Mac Chrome

    @renderAxes()

    @gl.flush()
    return

  setUniforms: ->
    @gl.uniform1f(@program.uEdgeThickness, @edgeThickness)
    @gl.uniform3fv(@program.uEdgeColor, @edgeColor)
    @gl.uniformMatrix4fv(@program.uMVMatrix, false, @mvMatrix)
    @gl.uniformMatrix4fv(@program.uPMatrix, false, @pMatrix)
    @gl.uniformMatrix4fv(@program.uNMatrix, false, @nMatrix)

    # direction of light source defined in world space, then transformed to view space
    lightDirection = vec3.createNormalize(@lightDirection) # world space
    mat4.multiplyVec3(@nMatrix, lightDirection) # view space
    @gl.uniform3fv(@program.uLightDirection, lightDirection)

    @gl.uniform3fv(@program.uLightColor, @lightColor)
    return

  renderAxes: ->

    axisBuffer = @gl.createBuffer()
    @gl.bindBuffer(@gl.ARRAY_BUFFER, axisBuffer)
    @gl.vertexAttribPointer(@program.aMultiPurposeVector, 3, @gl.FLOAT, false, 0, 0)
    if @drawAxes
      @gl.uniform1i(@program.uAxis, true)

      for i in [0...3]
        axis = [0, 0, 0, 0, 0, 0]
        axis[i] = 65 # from [65, 0, 0] to [0, 0, 0] etc.
        color = [0, 0, 0]
        color[i] = 1
        @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(axis), @gl.STATIC_DRAW)
        @gl.uniform3fv(@program.uAxisColor, color)
        @gl.drawArrays(@gl.LINES, 0, 2)

      axis = [
        -50, 0, 0, 0, 0, 0 # negative x-axis (from [-50, 0, 0] to origin)
        0, 0, -50, 0, 0, 0 # negative z-axis (from [0, 0, -50] to origin)
      ]
      for i in [-50..50] by 5
        if i != 0
          axis.push(
            i,   0, -50,
            i,   0, 50, # one line parallel to the x-axis
            -50, 0, i,
            50,  0, i   # one line parallel to the z-axis
          )
      color = [0.7, 0.7, 0.7]
      @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(axis), @gl.STATIC_DRAW)
      @gl.uniform3fv(@program.uAxisColor, color)
      @gl.drawArrays(@gl.LINES, 0, 84)

      @gl.uniform1i(@program.uAxis, false)

    # draw center point
    if @drawCenterPoint
      @gl.uniform1i(@program.uCenterPoint, true)
      @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(@center), @gl.STATIC_DRAW)
      @gl.drawArrays(@gl.POINTS, 0, 1)
      @gl.uniform1i(@program.uCenterPoint, false)

    @gl.deleteBuffer(axisBuffer)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
    return

  registerKeyListener: (element) ->
    element.addEventListener('keydown', (e) =>
      switch e.keyCode + e.shiftKey * 1000 + e.ctrlKey * 10000 + e.altKey * 100000
        when 37 then @roty += Math.PI / 12 # left
        when 39 then @roty -= Math.PI / 12 # right
        when 38 then @rotx += Math.PI / 12 # up
        when 40 then @rotx -= Math.PI / 12 # down
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

  addCameraLightMotion: (motion, merge_flag, frame_offset) ->
    @motionManager.addCameraLightMotion(motion, merge_flag, frame_offset)
    return

  # addModelMotion: (model, motion, merge_flag, frame_offset) ->
  #   @motionManager.addModelMotion(model, motion, merge_flag, frame_offset)
  #   return

  addModelMotion: (modelName, motion, merge_flag, frame_offset) ->
    @motionManager.addModelMotion(@getModelRenderer(modelName).model, motion, merge_flag, frame_offset)
    return

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

