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
    positions = new Float32Array(length * 3)
    normals = new Float32Array(length * 3)
    uvs = new Float32Array(length * 2)
    # appendix_uvs = new Float32Array(length * model.appendix_uv)
    # weight_types = new Float32Array(length)

    for i in [0...length]
      vertex = model.vertices[i]
      positions[3 * i    ] = vertex.x
      positions[3 * i + 1] = vertex.y
      positions[3 * i + 2] = vertex.z
      normals[3 * i    ] = vertex.nx
      normals[3 * i + 1] = vertex.ny
      normals[3 * i + 2] = vertex.nz
      uvs[2 * i    ] = vertex.u
      uvs[2 * i + 1] = vertex.v
    
    for data in [
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
    return

  moveModel: ->
    return

  moveMorphs: (model, morphs) ->
    return

  moveBones: (model, bones) ->
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
    # motionManager = new MMD.MotionManager
    # motionManager.addModelMotion(@model, motion, merge_flag, frame_offset)
    # @motions[motionName] = motionManager

  play: (motionName) ->
    @playing = true
    # @motionManager = @motions[motionName]
    # if not @motionManager then console.log "#{motionName} not found in the motions"
    # @frame = -1
