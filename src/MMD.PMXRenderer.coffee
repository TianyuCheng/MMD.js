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
        positions1[3 * i    ] = bone1.head_pos[0]
        positions1[3 * i + 1] = bone1.head_pos[1]
        positions1[3 * i + 2] = bone1.head_pos[2]
        weights[4 * i] = 1
      if vertex.weight_type >= 1
        bone2 = model.bones[vertex.bone_num2]
        rotations2[4 * i + 3] = 1
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
    model.morphVec = morphVec
    
    for data in [
      {attribute: 'aMultiPurposeVector', array: morphVec, size: 3},
      {attribute: 'aWeightType', array: weightTypes, size: 1},
      {attribute: 'aBoneWeights', array: weights, size: 4},
      {attribute: 'aBone1Position', array: positions1, size: 3},
      {attribute: 'aBone2Position', array: positions2, size: 3},
      {attribute: 'aBone3Position', array: positions3, size: 3},
      {attribute: 'aBone4Position', array: positions4, size: 3},
      {attribute: 'aBone1Rotation', array: rotations1, size: 4},
      {attribute: 'aBone2Rotation', array: rotations2, size: 4},
      {attribute: 'aBone3Rotation', array: rotations3, size: 4},
      {attribute: 'aBone4Rotation', array: rotations4, size: 4},
      {attribute: 'aVertexPosition', array: positions, size: 3},
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

    # @gl.drawElements(@gl.TRIANGLES, @model.triangles.length, @gl.UNSIGNED_SHORT, 0)

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
    # not implemented
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
