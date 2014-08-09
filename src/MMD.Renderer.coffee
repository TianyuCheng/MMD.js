class this.MMD.Renderer

  constructor: (@mmd, @model) ->
    @gl = @mmd.gl
    @program = @mmd.program
    @vbuffers = {}
    @initVertices()
    @initIndices()
    @initTextures()
    @initMatrices()

    @motions = {}
    @playing = false
    @frame = -1
    return

  initVertices: ->
    model = @model

    length = model.vertices.length
    weight = new Float32Array(length)
    vectors1 = new Float32Array(3 * length)
    vectors2 = new Float32Array(3 * length)
    rotations1 = new Float32Array(4 * length)
    rotations2 = new Float32Array(4 * length)
    positions1 = new Float32Array(3 * length)
    positions2 = new Float32Array(3 * length)
    morphVec = new Float32Array(3 * length)
    normals = new Float32Array(3 * length)
    uvs = new Float32Array(2 * length)
    edge = new Float32Array(length)
    for i in [0...length]
      vertex = model.vertices[i]
      bone1 = model.bones[vertex.bone_num1]
      bone2 = model.bones[vertex.bone_num2]
      weight[i] = vertex.bone_weight
      vectors1[3 * i    ] = vertex.x - bone1.head_pos[0]
      vectors1[3 * i + 1] = vertex.y - bone1.head_pos[1]
      vectors1[3 * i + 2] = vertex.z - bone1.head_pos[2]
      vectors2[3 * i    ] = vertex.x - bone2.head_pos[0]
      vectors2[3 * i + 1] = vertex.y - bone2.head_pos[1]
      vectors2[3 * i + 2] = vertex.z - bone2.head_pos[2]
      positions1[3 * i    ] = bone1.head_pos[0]
      positions1[3 * i + 1] = bone1.head_pos[1]
      positions1[3 * i + 2] = bone1.head_pos[2]
      positions2[3 * i    ] = bone2.head_pos[0]
      positions2[3 * i + 1] = bone2.head_pos[1]
      positions2[3 * i + 2] = bone2.head_pos[2]
      rotations1[4 * i + 3] = 1
      rotations2[4 * i + 3] = 1
      normals[3 * i    ] = vertex.nx
      normals[3 * i + 1] = vertex.ny
      normals[3 * i + 2] = vertex.nz
      uvs[2 * i    ] = vertex.u
      uvs[2 * i + 1] = vertex.v
      edge[i] = 1 - vertex.edge_flag
    model.rotations1 = rotations1
    model.rotations2 = rotations2
    model.positions1 = positions1
    model.positions2 = positions2
    model.morphVec = morphVec

    for data in [
      {attribute: 'aBoneWeight', array: weight, size: 1},
      {attribute: 'aVectorFromBone1', array: vectors1, size: 3},
      {attribute: 'aVectorFromBone2', array: vectors2, size: 3},
      {attribute: 'aBone1Rotation', array: rotations1, size: 4},
      {attribute: 'aBone2Rotation', array: rotations2, size: 4},
      {attribute: 'aBone1Position', array: positions1, size: 3},
      {attribute: 'aBone2Position', array: positions2, size: 3},
      {attribute: 'aMultiPurposeVector', array: morphVec, size: 3},
      {attribute: 'aVertexNormal', array: normals, size: 3},
      {attribute: 'aTextureCoord', array: uvs, size: 2},
      {attribute: 'aVertexEdge', array: edge, size: 1},
    ]
      buffer = @gl.createBuffer()
      @gl.bindBuffer(@gl.ARRAY_BUFFER, buffer)
      @gl.bufferData(@gl.ARRAY_BUFFER, data.array, @gl.STATIC_DRAW)
      @vbuffers[data.attribute] = {size: data.size, buffer: buffer}

    @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
    return

  initIndices: ->
    indices = @model.triangles

    @ibuffer = @gl.createBuffer()
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, @ibuffer)
    @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, indices, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, null)
    return

  initTextures: ->
    model = @model

    @textureManager = new MMD.TextureManager(this)
    @textureManager.onload = => @redraw = true

    for material in model.materials
      material.textures = {} if not material.textures

      toonIndex = material.toon_index
      fileName = 'toon' + ('0' + (toonIndex + 1)).slice(-2) + '.bmp'
      if toonIndex == -1 or # -1 is special (no shadow)
        !model.toon_file_names or # no toon_file_names section in PMD
        fileName == model.toon_file_names[toonIndex] # toonXX.bmp is in 'data' directory
          fileName = 'data/' + fileName
      else # otherwise the toon texture is in the model's directory
        fileName = model.directory + '/' + model.toon_file_names[toonIndex]
      material.textures.toon = @textureManager.get('toon', fileName)

      if material.texture_file_name
        for fileName in material.texture_file_name.split('*')
          switch fileName.slice(-4)
            when '.sph' then type = 'sph'
            when '.spa' then type = 'spa'
            when '.tga' then type = 'regular'; fileName += '.png'
            else             type = 'regular'
          material.textures[type] = @textureManager.get(type, model.directory + '/' + fileName)

    return

  render: ->

    for attribute, vb of @vbuffers
      @gl.bindBuffer(@gl.ARRAY_BUFFER, vb.buffer)
      @gl.vertexAttribPointer(@program[attribute], vb.size, @gl.FLOAT, false, 0, 0)

    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, @ibuffer)

    @gl.enable(@gl.CULL_FACE)
    @gl.enable(@gl.BLEND)
    @gl.blendFuncSeparate(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA, @gl.SRC_ALPHA, @gl.DST_ALPHA)

    offset = 0
    for material in @model.materials
      @renderMaterial(material, offset)
      offset += material.face_vert_count

    @gl.disable(@gl.BLEND)

    offset = 0
    for material in @model.materials
      @renderEdge(material, offset)
      offset += material.face_vert_count

    # @setSelfShadowTexture()
    # @setUniforms()

  renderMaterial: (material, offset) ->
    @gl.uniform3fv(@program.uAmbientColor, material.ambient)
    @gl.uniform3fv(@program.uSpecularColor, material.specular)
    @gl.uniform3fv(@program.uDiffuseColor, material.diffuse)
    @gl.uniform1f(@program.uAlpha, material.alpha)
    @gl.uniform1f(@program.uShininess, material.shininess)
    @gl.uniform1i(@program.uEdge, false)

    textures = material.textures

    @gl.activeTexture(@gl.TEXTURE0) # 0 -> toon
    @gl.bindTexture(@gl.TEXTURE_2D, textures.toon)
    @gl.uniform1i(@program.uToon, 0)

    if textures.regular
      @gl.activeTexture(@gl.TEXTURE1) # 1 -> regular texture
      @gl.bindTexture(@gl.TEXTURE_2D, textures.regular)
      @gl.uniform1i(@program.uTexture, 1)
    @gl.uniform1i(@program.uUseTexture, !!textures.regular)

    if textures.sph or textures.spa
      @gl.activeTexture(@gl.TEXTURE2) # 2 -> sphere map texture
      @gl.bindTexture(@gl.TEXTURE_2D, textures.sph || textures.spa)
      @gl.uniform1i(@program.uSphereMap, 2)
      @gl.uniform1i(@program.uUseSphereMap, true)
      @gl.uniform1i(@program.uIsSphereMapAdditive, !!textures.spa)
    else
      @gl.uniform1i(@program.uUseSphereMap, false)

    @gl.cullFace(@gl.BACK)

    @gl.drawElements(@gl.TRIANGLES, material.face_vert_count, @gl.UNSIGNED_SHORT, offset * 2)

    return

  renderEdge: (material, offset) ->
    return if not @drawEdge or not material.edge_flag

    @gl.uniform1i(@program.uEdge, true)
    @gl.cullFace(@gl.FRONT)

    @gl.drawElements(@gl.TRIANGLES, material.face_vert_count, @gl.UNSIGNED_SHORT, offset * 2)

    @gl.cullFace(@gl.BACK)
    @gl.uniform1i(@program.uEdge, false)

  setSelfShadowTexture: ->
    return if not @mmd.drawSelfShadow
    @shadowMap = @mmd.shadowMap
    model = @model

    @shadowMap.computeMatrices()
    @shadowMap.beforeRender()

    offset = 0
    for material in model.materials
      continue if 0.979 < material.alpha < 0.981 # alpha is 0.98

      @gl.drawElements(@gl.TRIANGLES, material.face_vert_count, @gl.UNSIGNED_SHORT, offset * 2)
      offset += material.face_vert_count

    @shadowMap.afterRender()

    @gl.activeTexture(@gl.TEXTURE3) # 3 -> shadow map
    @gl.bindTexture(@gl.TEXTURE_2D, @shadowMap.getTexture())
    @gl.uniform1i(@program.uShadowMap, 3)
    @gl.uniformMatrix4fv(@program.uLightMatrix, false, @shadowMap.getLightMatrix())
    @gl.uniform1i(@program.uSelfShadow, true)

    return

  move: ->
    # @motionManager = @mmd.motionManager
    if not @playing or not @motionManager then return
    if ++@frame > @motionManager.lastFrame
      @frame = -1
      @playing = false
      return

    # @moveCamera()
    # @moveLight()

    @moveModel()
    return

  # moveCamera: ->
  #   camera = @motionManager.getCameraFrame(@frame)
  #   if camera and not @ignoreCameraMotion
  #     @distance = camera.distance
  #     @rotx = camera.rotation[0]
  #     @roty = camera.rotation[1]
  #     @center = vec3.create(camera.location)
  #     @fovy = camera.view_angle
  #
  #   return
  #
  # moveLight: ->
  #   light = @motionManager.getLightFrame(@frame)
  #   if light
  #     @lightDirection = light.location
  #     @lightColor = light.color
  #
  #   return


  moveModel: ->
    {morphs, bones} = @motionManager.getModelFrame(@model, @frame)

    @moveMorphs(@model, morphs)
    @moveBones(@model, bones)
    return

  moveMorphs: (model, morphs) ->
    return if not morphs
    return if model.morphs.length == 0

    for morph, j in model.morphs
      if j == 0
        base = morph
        continue
      continue if morph.name not of morphs
      weight = morphs[morph.name]
      for vert in morph.vert_data
        b = base.vert_data[vert.index]
        i = b.index
        model.morphVec[3 * i    ] += vert.x * weight
        model.morphVec[3 * i + 1] += vert.y * weight
        model.morphVec[3 * i + 2] += vert.z * weight

    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aMultiPurposeVector.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, model.morphVec, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, null)

    # reset positions
    for b in base.vert_data
      i = b.index
      model.morphVec[3 * i    ] = 0
      model.morphVec[3 * i + 1] = 0
      model.morphVec[3 * i + 2] = 0

    return

  moveBones: (model, bones) ->
    return if not bones

    # individualBoneMotions is translation/rotation of each bone from it's original position
    # boneMotions is total position/rotation of each bone
    # boneMotions is an array like [{p, r, tainted}]
    # tainted flag is used to avoid re-creating vec3/quat4
    individualBoneMotions = []
    boneMotions = []
    originalBonePositions = []
    parentBones = []
    constrainedBones = []

    for bone, i in model.bones
      individualBoneMotions[i] = bones[bone.name] ? {
        rotation: quat4.create([0, 0, 0, 1])
        location: vec3.create()
      }
      boneMotions[i] = {
        r: quat4.create()
        p: vec3.create()
        tainted: true
      }
      originalBonePositions[i] = bone.head_pos
      parentBones[i] = bone.parent_bone_index
      if bone.name.indexOf('\u3072\u3056') > 0 # ひざ
        constrainedBones[i] = true # TODO: for now it's only for knees, but extend this if I do PMX

    getBoneMotion = (boneIndex) ->
      # http://d.hatena.ne.jp/edvakf/20111026/1319656727
      motion = boneMotions[boneIndex]
      return motion if motion and not motion.tainted

      m = individualBoneMotions[boneIndex]
      r = quat4.set(m.rotation, motion.r)
      t = m.location
      p = vec3.set(originalBonePositions[boneIndex], motion.p)

      if parentBones[boneIndex] == 0xFFFF # center, foot IK, etc.
        return boneMotions[boneIndex] = {
          p: vec3.add(p, t),
          r: r
          tainted: false
        }
      else
        parentIndex = parentBones[boneIndex]
        parentMotion = getBoneMotion(parentIndex)
        r = quat4.multiply(parentMotion.r, r, r)
        p = vec3.subtract(p, originalBonePositions[parentIndex])
        vec3.add(p, t)
        vec3.rotateByQuat4(p, parentMotion.r)
        vec3.add(p, parentMotion.p)
        return boneMotions[boneIndex] = {p: p, r: r, tainted: false}

    resolveIKs = ->
      # this function is run only once, but to narrow the scope I'm making a function
      # http://d.hatena.ne.jp/edvakf/20111102/1320268602

      # objects to be reused
      targetVec = vec3.create()
      ikboneVec = vec3.create()
      axis = vec3.create()
      tmpQ = quat4.create()
      tmpR = quat4.create()

      for ik in model.iks
        ikbonePos = getBoneMotion(ik.bone_index).p
        targetIndex = ik.target_bone_index
        minLength = 0.1 * vec3.length(
          vec3.subtract(
            originalBonePositions[targetIndex],
            originalBonePositions[parentBones[targetIndex]], axis)) # temporary use of axis

        for n in [0...ik.iterations]
          targetPos = getBoneMotion(targetIndex).p # this should calculate the whole chain
          break if minLength > vec3.length(
            vec3.subtract(targetPos, ikbonePos, axis)) # temporary use of axis

          for boneIndex, i in ik.child_bones
            motion = getBoneMotion(boneIndex)
            bonePos = motion.p
            targetPos = getBoneMotion(targetIndex).p if i > 0
            targetVec = vec3.subtract(targetPos, bonePos, targetVec)
            targetVecLen = vec3.length(targetVec)
            continue if targetVecLen < minLength # targetPos == bonePos
            ikboneVec = vec3.subtract(ikbonePos, bonePos, ikboneVec)
            ikboneVecLen = vec3.length(ikboneVec)
            continue if ikboneVecLen < minLength # ikbonePos == bonePos
            axis = vec3.cross(targetVec, ikboneVec, axis)
            axisLen = vec3.length(axis)
            sinTheta = axisLen / ikboneVecLen / targetVecLen
            continue if sinTheta < 0.001 # ~0.05 degree
            maxangle = (i + 1) * ik.control_weight * 4 # angle to move in one iteration
            theta = Math.asin(sinTheta)
            theta = 3.141592653589793 - theta if vec3.dot(targetVec, ikboneVec) < 0
            theta = maxangle if theta > maxangle
            q = quat4.set(vec3.scale(axis, Math.sin(theta / 2) / axisLen), tmpQ) # q is tmpQ
            q[3] = Math.cos(theta / 2)
            parentRotation = getBoneMotion(parentBones[boneIndex]).r
            r = quat4.inverse(parentRotation, tmpR) # r is tmpR
            r = quat4.multiply(quat4.multiply(r, q), motion.r)

            if constrainedBones[boneIndex]
              c = r[3] # cos(theta / 2)
              r = quat4.set([Math.sqrt(1 - c * c), 0, 0, c], r) # axis must be x direction
              quat4.inverse(boneMotions[boneIndex].r, q)
              quat4.multiply(r, q, q)
              q = quat4.multiply(parentRotation, q, q)

            # update individualBoneMotions[boneIndex].rotation
            quat4.normalize(r, individualBoneMotions[boneIndex].rotation)
            # update boneMotions[boneIndex].r which is the same as motion.r
            quat4.multiply(q, motion.r, motion.r)

            # taint for re-calculation
            boneMotions[ik.child_bones[j]].tainted = true for j in [0...i]
            boneMotions[ik.target_bone_index].tainted = true

    resolveIKs()

    # calculate positions/rotations of bones other than IK
    getBoneMotion(i) for i in [0...model.bones.length]

    #TODO: split

    rotations1 = model.rotations1
    rotations2 = model.rotations2
    positions1 = model.positions1
    positions2 = model.positions2

    length = model.vertices.length
    for i in [0...length]
      vertex = model.vertices[i]
      motion1 = boneMotions[vertex.bone_num1]
      motion2 = boneMotions[vertex.bone_num2]
      rot1 = motion1.r
      pos1 = motion1.p
      rot2 = motion2.r
      pos2 = motion2.p
      rotations1[i * 4    ] = rot1[0]
      rotations1[i * 4 + 1] = rot1[1]
      rotations1[i * 4 + 2] = rot1[2]
      rotations1[i * 4 + 3] = rot1[3]
      rotations2[i * 4    ] = rot2[0]
      rotations2[i * 4 + 1] = rot2[1]
      rotations2[i * 4 + 2] = rot2[2]
      rotations2[i * 4 + 3] = rot2[3]
      positions1[i * 3    ] = pos1[0]
      positions1[i * 3 + 1] = pos1[1]
      positions1[i * 3 + 2] = pos1[2]
      positions2[i * 3    ] = pos2[0]
      positions2[i * 3 + 1] = pos2[1]
      positions2[i * 3 + 2] = pos2[2]

    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations1, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations2, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions1, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions2, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
    return

  initMatrices: ->
    @modelMatrix = mat4.createIdentity()

  translate: (x, y, z) ->
    mat4.translate(@modelMatrix, [x, y, z])

  scale: (x, y, z) ->
    mat4.scale(@modelMatrix, [x, y, z])

  rotate: (angle, x, y, z) ->
    mat4.rotate(@modelMatrix, angle, [x, y, z])

  addModelMotion: (motionName, motion, merge_flag, frame_offset) ->
    motionManager = new MMD.MotionManager
    motionManager.addModelMotion(@model, motion, merge_flag, frame_offset)
    # @mmd.motionManager.addModelMotion(@model, motion, merge_flag, frame_offset)
    @motions[motionName] = motionManager

  play: (motionName) ->
    @playing = true
    @motionManager = @motions[motionName]
    if not @motion then console.err "#{motionName} not found in the motions"
    @frame = -1
