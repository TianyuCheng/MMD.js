class this.MMD.PMXRenderer

  constructor: (@mmd, @model) ->
    @gl = @mmd.gl
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
    weightTypes = new Float32Array(length)
    weights = new Float32Array(length * 4)
    vectors1 = new Float32Array(length * 3)
    vectors2 = new Float32Array(length * 3)
    vectors3 = new Float32Array(length * 3)
    vectors4 = new Float32Array(length * 3)
    positions1 = new Float32Array(length * 3)
    positions2 = new Float32Array(length * 3)
    positions3 = new Float32Array(length * 3)
    positions4 = new Float32Array(length * 3)
    rotations1 = new Float32Array(length * 4)
    rotations2 = new Float32Array(length * 4)
    rotations3 = new Float32Array(length * 4)
    rotations4 = new Float32Array(length * 4)
    morphVec = new Float32Array(3 * length)
    sdefC = new Float32Array(length * 3)
    sdefR0 = new Float32Array(length * 3)
    sdefR1 = new Float32Array(length * 3)
    positions = new Float32Array(length * 3)
    normals = new Float32Array(length * 3)
    uvs = new Float32Array(length * 2)
    # appendix_uvs = new Float32Array(length * model.appendix_uv)

    for i in [0...length]
      vertex = model.vertices[i]
      weightTypes[i] = vertex.weight_type
      if vertex.weight_type >= 0
        bone1 = model.bones[vertex.bone_num1]
        rotations1[4 * i + 3] = 1
        vectors1[3 * i    ] = vertex.x - bone1.head_pos[0]
        vectors1[3 * i + 1] = vertex.y - bone1.head_pos[1]
        vectors1[3 * i + 2] = vertex.z - bone1.head_pos[2]
        positions1[3 * i    ] = bone1.head_pos[0]
        positions1[3 * i + 1] = bone1.head_pos[1]
        positions1[3 * i + 2] = bone1.head_pos[2]
        weights[4 * i] = 1
      if vertex.weight_type >= 1
        bone2 = model.bones[vertex.bone_num2]
        rotations2[4 * i + 3] = 1
        vectors2[3 * i    ] = vertex.x - bone2.head_pos[0]
        vectors2[3 * i + 1] = vertex.y - bone2.head_pos[1]
        vectors2[3 * i + 2] = vertex.z - bone2.head_pos[2]
        positions2[3 * i    ] = bone2.head_pos[0]
        positions2[3 * i + 1] = bone2.head_pos[1]
        positions2[3 * i + 2] = bone2.head_pos[2]
        weights[4 * i    ] = vertex.bone_weight1
        weights[4 * i + 1] = 1 - vertex.bone_weight1
      if vertex.weight_type is 2
        bone3 = model.bones[vertex.bone_num3]
        bone4 = model.bones[vertex.bone_num4]
        rotations3[4 * i + 3] = 1
        rotations4[4 * i + 3] = 1
        vectors3[3 * i    ] = vertex.x - bone3.head_pos[0]
        vectors3[3 * i + 1] = vertex.y - bone3.head_pos[1]
        vectors3[3 * i + 2] = vertex.z - bone3.head_pos[2]
        vectors4[3 * i    ] = vertex.x - bone4.head_pos[0]
        vectors4[3 * i + 1] = vertex.y - bone4.head_pos[1]
        vectors4[3 * i + 2] = vertex.z - bone4.head_pos[2]
        positions3[3 * i    ] = bone3.head_pos[0]
        positions3[3 * i + 1] = bone3.head_pos[1]
        positions3[3 * i + 2] = bone3.head_pos[2]
        positions4[3 * i    ] = bone4.head_pos[0]
        positions4[3 * i + 1] = bone4.head_pos[1]
        positions4[3 * i + 2] = bone4.head_pos[2]
        weights[4 * i    ] = vertex.bone_weight1
        weights[4 * i + 1] = vertex.bone_weight2
        weights[4 * i + 2] = vertex.bone_weight3
        weights[4 * i + 3] = vertex.bone_weight4
      if vertex.weight_type is 3
        sdefC[3 * i    ] = vertex.C[0]
        sdefC[3 * i + 1] = vertex.C[1]
        sdefC[3 * i + 2] = vertex.C[2]
        sdefR0[3 * i    ] = vertex.R0[0]
        sdefR0[3 * i + 1] = vertex.R0[1]
        sdefR0[3 * i + 2] = vertex.R0[2]
        sdefR1[3 * i    ] = vertex.R1[0]
        sdefR1[3 * i + 1] = vertex.R1[1]
        sdefR1[3 * i + 2] = vertex.R1[2]

      positions[3 * i    ] = vertex.x
      positions[3 * i + 1] = vertex.y
      positions[3 * i + 2] = vertex.z
      normals[3 * i    ] = vertex.nx
      normals[3 * i + 1] = vertex.ny
      normals[3 * i + 2] = vertex.nz
      uvs[2 * i    ] = vertex.u
      uvs[2 * i + 1] = vertex.v

    model.rotations1 = rotations1
    model.rotations2 = rotations2
    model.rotations3 = rotations3
    model.rotations4 = rotations4
    model.positions1 = positions1
    model.positions2 = positions2
    model.positions3 = positions3
    model.positions4 = positions4
    model.morphVec = morphVec
    
    for data in [
      # {attribute: 'aMultiPurposeVector', array: morphVec, size: 3},
      {attribute: 'aWeightType', array: weightTypes, size: 1},
      {attribute: 'aBoneWeights', array: weights, size: 4},
      {attribute: 'aVectorFromBone1', array: vectors1, size: 3},
      {attribute: 'aVectorFromBone2', array: vectors2, size: 3},
      {attribute: 'aVectorFromBone3', array: vectors3, size: 3},
      {attribute: 'aVectorFromBone4', array: vectors4, size: 3},
      {attribute: 'aBone1Position', array: positions1, size: 3},
      {attribute: 'aBone2Position', array: positions2, size: 3},
      {attribute: 'aBone3Position', array: positions3, size: 3},
      {attribute: 'aBone4Position', array: positions4, size: 3},
      {attribute: 'aBone1Rotation', array: rotations1, size: 4},
      {attribute: 'aBone2Rotation', array: rotations2, size: 4},
      {attribute: 'aBone3Rotation', array: rotations3, size: 4},
      {attribute: 'aBone4Rotation', array: rotations4, size: 4},
      # {attribute: 'aVertexPosition', array: positions, size: 3},
      {attribute: 'aVertexNormal', array: normals, size: 3},
      {attribute: 'aTextureCoord', array: uvs, size: 2}
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

    @textureManager = new MMD.TextureManager(@mmd)
    @textureManager.onload = => @redraw = true

    for material in model.materials
      material.textures = {} if not material.textures

      toonFlag = material.toon_flag
      toonIndex = material.toon_index
      if toonFlag is 1   # toonFlag == 1, toonIndex from 0-9
        fileName = 'toon' + ('0' + (toonIndex + 1)).slice(-2) + '.bmp'
        if toonIndex == -1 or # -1 is special (no shadow)
          !model.toon_file_names or # no toon_file_names section in PMX
          fileName == model.toon_file_names[toonIndex] # toonXX.bmp is in 'data' directory
            fileName = 'data/' + fileName
        else # otherwise the toon texture is in the model's directory
          fileName = model.directory + '/' + model.toon_file_names[toonIndex]
        material.textures.toon = @textureManager.get('toon', fileName)
      else if toonFlag is 0 and toonIndex >= 0 # toonFlag == 0, toonIndex from textures
        fileName = model.textures[toonIndex]
        material.textures.toon = @textureManager.get('toon', model.directory + '/' + fileName)
    
      # load textures
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
    @mmd.setPMXUniforms()
    @program = @mmd.pmxProgram

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
    return

  renderMaterial: (material, offset) ->
    @gl.uniform3fv(@program.uAmbientColor, material.ambient)
    @gl.uniform3fv(@program.uSpecularColor, material.specular)
    @gl.uniform3fv(@program.uDiffuseColor, material.diffuse)
    @gl.uniform1f(@program.uAlpha, material.alpha)
    @gl.uniform1f(@program.uShininess, material.shininess)

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

    length = material.face_vert_count
    # draw elements with proper size
    switch @model.vertex_index_size
      when 1    # unsigned byte
        @gl.drawElements(@gl.TRIANGLES, length, @gl.UNSIGNED_BYTE, offset)
      when 2    # unsigned short
        @gl.drawElements(@gl.TRIANGLES, length, @gl.UNSIGNED_SHORT, offset * 2)
      when 4    # unsigned int
        @gl.drawElements(@gl.TRIANGLES, length, @gl.UNSIGNED_INT, offset * 4)
      else
        console.log "vertex index size not found #{@model.vertex_index_size}"
    return

  renderEdge: (material, offset) ->
    # return if not @drawEdge or not material.edge_flag
    return

  move: ->
    if not @playing or not @motionManager then return
    if ++@frame > @motionManager.lastFrame
      @frame = -1
      @playing = false
      return

    # @frame = 0

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

    # for morph, j in model.morphs
    #   if j == 0
    #     base = morph
    #     continue
    #   continue if morph.name not of morphs
    #   weight = morphs[morph.name]
    #   for vert in morph.vert_data
    #     b = base.vert_data[vert.index]
    #     i = b.index
    #     model.morphVec[3 * i    ] += vert.x * weight
    #     model.morphVec[3 * i + 1] += vert.y * weight
    #     model.morphVec[3 * i + 2] += vert.z * weight
    #
    # @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aMultiPurposeVector.buffer)
    # @gl.bufferData(@gl.ARRAY_BUFFER, model.morphVec, @gl.STATIC_DRAW)
    # @gl.bindBuffer(@gl.ARRAY_BUFFER, null)
    #
    # # reset positions
    # for b in base.vert_data
    #   i = b.index
    #   model.morphVec[3 * i    ] = 0
    #   model.morphVec[3 * i + 1] = 0
    #   model.morphVec[3 * i + 2] = 0

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
      if bone.rad_limited
        contrainedBones[i] = true

    getBoneMotion = (boneIndex) ->
      motion = boneMotions[boneIndex]
      return motion if motion and not motion.tainted

      m = individualBoneMotions[boneIndex]
      r = quat4.set(m.rotation, motion.r)
      t = m.location
      p = vec3.set(originalBonePositions[boneIndex], motion.p)

      if parentBones[boneIndex] == -1 # center, foot IK, etc.
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

      for bone, bone_index in model.bones
        continue if not bone.ik_flag?        # ik stored in bones, skip if this bone is not IK
        ik = bone
        ikbonePos = getBoneMotion(bone_index).p
        targetIndex = ik.target_bone_index
        minLength = 0.1 * vec3.length(
          vec3.subtract(
            originalBonePositions[targetIndex],
            originalBonePositions[parentBones[targetIndex]], axis)) # temporary use of axis

        for n in [0...ik.iterations]
          targetPos = getBoneMotion(targetIndex).p # this should calculate the whole chain
          break if minLength > vec3.length(
            vec3.subtract(targetPos, ikbonePos, axis)) # temporary use of axis

          for child_bones, i in ik.child_bones
            boneIndex = child_bones.link_index
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
            # boneMotions[ik.child_bones[j]].tainted = true for j in [0...i]
            boneMotions[ik.target_bone_index].tainted = true

    resolveIKs()

    # calculate positions/rotations of bones other than IK
    getBoneMotion(i) for i in [0...model.bones.length]

    #TODO: split

    rotations1 = model.rotations1
    rotations2 = model.rotations2
    rotations3 = model.rotations3
    rotations4 = model.rotations4
    positions1 = model.positions1
    positions2 = model.positions2
    positions3 = model.positions3
    positions4 = model.positions4

    length = model.vertices.length
    for i in [0...length]
      vertex = model.vertices[i]
      if vertex.weight_type >= 0    # BDEF 1
        motion1 = boneMotions[vertex.bone_num1]
        rot1 = motion1.r
        pos1 = motion1.p
        rotations1[i * 4    ] = rot1[0]
        rotations1[i * 4 + 1] = rot1[1]
        rotations1[i * 4 + 2] = rot1[2]
        rotations1[i * 4 + 3] = rot1[3]
        positions1[i * 3    ] = pos1[0]
        positions1[i * 3 + 1] = pos1[1]
        positions1[i * 3 + 2] = pos1[2]
      if vertex.weight_type >= 1    # BDEF 2
        motion2 = boneMotions[vertex.bone_num2]
        rot2 = motion2.r
        pos2 = motion2.p
        rotations2[i * 4    ] = rot2[0]
        rotations2[i * 4 + 1] = rot2[1]
        rotations2[i * 4 + 2] = rot2[2]
        rotations2[i * 4 + 3] = rot2[3]
        positions2[i * 3    ] = pos2[0]
        positions2[i * 3 + 1] = pos2[1]
        positions2[i * 3 + 2] = pos2[2]
      if vertex.weight_type == 2    # BDEF 4
        motion3 = boneMotions[vertex.bone_num3]
        motion4 = boneMotions[vertex.bone_num4]
        # motion3
        rot3 = motion3.r
        pos3 = motion3.p
        rotations3[i * 4    ] = rot3[0]
        rotations3[i * 4 + 1] = rot3[1]
        rotations3[i * 4 + 2] = rot3[2]
        rotations3[i * 4 + 3] = rot3[3]
        positions3[i * 3    ] = pos3[0]
        positions3[i * 3 + 1] = pos3[1]
        positions3[i * 3 + 2] = pos3[2]
        # motion4
        rot4 = motion4.r
        pos4 = motion4.p
        rotations4[i * 4    ] = rot4[0]
        rotations4[i * 4 + 1] = rot4[1]
        rotations4[i * 4 + 2] = rot4[2]
        rotations4[i * 4 + 3] = rot4[3]
        positions4[i * 3    ] = pos4[0]
        positions4[i * 3 + 1] = pos4[1]
        positions4[i * 3 + 2] = pos4[2]

      if vertex.weight_type == 4    # SDEF
        # not implemented
        null

    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations1, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations2, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone3Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations3, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone4Rotation.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, rotations4, @gl.STATIC_DRAW)

    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone1Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions1, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone2Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions2, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone3Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions3, @gl.STATIC_DRAW)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbuffers.aBone4Position.buffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, positions4, @gl.STATIC_DRAW)
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
    @motions[motionName] = motionManager

  play: (motionName) ->
    @playing = true
    @motionManager = @motions[motionName]
    if not @motionManager then console.log "#{motionName} not found in the motions"
    @frame = -1
