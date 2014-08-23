class this.MMD.PMXRenderer

  constructor: (@mmd, @model) ->
    @gl = @mmd.gl
    @program = @mmd.pmxProgram
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
      {attribute: 'aVertexPosition', array: positions, size: 3}
      # {attribute: 'aVertexNormal', array: normals, size: 3},
      # {attribute: 'aTextureCoord', array: uvs, size: 2}
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
    return

  render: ->
    @mmd.setPMXUniforms()

    for attribute, vb of @vbuffers
      @gl.bindBuffer(@gl.ARRAY_BUFFER, vb.buffer)
      @gl.vertexAttribPointer(@program[attribute], vb.size, @gl.FLOAT, false, 0, 0)

    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, @ibuffer)

    if @model.vertex_index_size == 2
        @gl.drawElements(@gl.TRIANGLES, @model.triangles.length, @gl.UNSIGNED_SHORT, 0)
    else if @model.vertex_index_size == 4
        @gl.drawElements(@gl.TRIANGLES, @model.triangles.length, @gl.UNSIGNED_INT, 0)

  renderMaterial: (material, offset) ->
    # @gl.drawElements(@gl.TRIANGLES, material.face_vert_count, @gl.UNSIGNED_SHORT, offset * 2)
    return

  renderEdge: (material, offset) ->
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
    # @playing = true
    # @motionManager = @motions[motionName]
    # if not @motionManager then console.log "#{motionName} not found in the motions"
    # @frame = -1
