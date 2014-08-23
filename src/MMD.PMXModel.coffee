# for PMX 2.0

# some shorthands
size_Int8 = Int8Array.BYTES_PER_ELEMENT
size_Uint8 = Uint8Array.BYTES_PER_ELEMENT
size_Uint16 = Uint16Array.BYTES_PER_ELEMENT
size_Uint32 = Uint32Array.BYTES_PER_ELEMENT
size_Float32 = Float32Array.BYTES_PER_ELEMENT

slice = Array.prototype.slice

DataView.prototype.getBySize = (offset, size, littleEndian = false) ->
  switch size
    when size_Uint8
      return @getInt8(offset)
    when size_Uint16
      return @getInt16(offset, littleEndian)
    when size_Uint32
      return @getInt32(offset, littleEndian)
    else
      throw "unsupported size #{size}"

DataView.prototype.getString = (offset, size, utf8Encoding = false) ->
  ret  = ""
  if utf8Encoding
    for i in [0...size]
      ret += String.fromCharCode(@getUint8(offset + i * size_Uint8))
  else
    size = size / 2
    for i in [0...size]
      ret += String.fromCharCode(@getUint16(offset + i * size_Uint16, true))
  return ret


class this.MMD.PMXModel # export to top level
  constructor: (directory, filename) ->
    @type = "PMX"
    @directory = directory
    @filename = filename
    @vertices = null
    @triangles = null
    @materials = null
    @textures = null
    @bones = null
    @morphs = null
    @morph_order = null
    @bone_group_names = null
    @bone_table = null
    @english_flag = null
    @english_name = null
    @english_comment = null
    @english_bone_names = null
    @english_morph_names = null
    @english_bone_group_names = null
    @toon_file_names = null
    @rigid_bodies = null
    @joints = null

    @encoding = null
    @utf8encoding = null
    @appendix_uv = null
    @vertex_index_size = null
    @texture_index_size = null
    @material_index_size = null
    @bone_index_size = null
    @morph_index_size = null
    @rigid_body_index_size = null

  load: (callback) ->
    xhr = new XMLHttpRequest
    xhr.open('GET', @directory + '/' + @filename, true)
    xhr.responseType = 'arraybuffer'
    xhr.onload = =>
      console.time("parse #{@filename}")
      @parse(xhr.response)
      console.timeEnd("parse #{@filename}")
      callback()
    xhr.send()

  parse: (buffer) ->
    length = buffer.byteLength
    view = new DataView(buffer, 0)
    offset = 0
    offset = @checkHeader(buffer, view, offset)
    offset = @getName(buffer, view, offset)
    offset = @getVertices(buffer, view, offset)
    offset = @getTriangles(buffer, view, offset)
    offset = @getTextures(buffer, view, offset)
    offset = @getMaterials(buffer, view, offset)
    offset = @getBones(buffer, view, offset)
    offset = @getMorphs(buffer, view, offset)
    offset = @getFrames(buffer, view, offset)
    offset = @getRigidBodies(buffer, view, offset)
    offset = @getJoints(buffer, view, offset)

  checkHeader: (buffer, view, offset) ->
    if view.getUint8(0) != 'P'.charCodeAt(0) or
       view.getUint8(1) != 'M'.charCodeAt(0) or
       view.getUint8(2) != 'X'.charCodeAt(0) or
       view.getUint8(3) != ' '.charCodeAt(0) or
       view.getUint8(4) != 0x00 or
       view.getUint8(5) != 0x00 or
       view.getUint8(6) != 0x00 or
       view.getUint8(7) != 0x40
      throw 'File is not PMX'

    # attributes
    @length = view.getUint8(8)
    @encoding = if view.getUint8(9) == 0 then "UTF-16" else "UTF-8"
    @utf8encoding = Boolean(view.getUint8(9))   # easier manipulation with bool
    @appendix_uv = view.getUint8(10)            # 0-4
    @vertex_index_size = view.getUint8(11)      # 1 = byte, 2 = short, 4 = int
    @texture_index_size = view.getUint8(12)     # 1 = byte, 2 = short, 4 = int
    @material_index_size = view.getUint8(13)    # 1 = byte, 2 = short, 4 = int
    @bone_index_size = view.getUint8(14)        # 1 = byte, 2 = short, 4 = int
    @morph_index_size = view.getUint8(15)       # 1 = byte, 2 = short, 4 = int
    @rigid_body_index_size = view.getUint8(16)  # 1 = byte, 2 = short, 4 = int
    offset += 17 * size_Uint8

  getName: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, length, @utf8encoding)
    offset += length * size_Uint8 + size_Uint32

    length = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, length, @utf8encoding)
    offset += length * size_Uint8 + size_Uint32

    length = view.getUint32(offset, true)
    @comment = view.getString(offset + size_Uint32, length, @utf8encoding)
    offset += length * size_Uint8 + size_Uint32

    length = view.getUint32(offset, true)
    @english_comment = view.getString(offset + size_Uint32, length, @utf8encoding)
    offset += length * size_Uint8 + size_Uint32

  getVertices: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @vertices =
      for i in [0...length]
        vertex = new PMXVertex(buffer, view, offset, this)
        offset += vertex.size
        vertex
    offset

  getTriangles: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @triangles = new Uint16Array(length)
    #left->right handed system (swap 0th and 1st vertices)
    for i in [0...length] by 3
      @triangles[i + 1] = view.getBySize(offset, @vertex_index_size, true); offset += @vertex_index_size
      @triangles[i    ] = view.getBySize(offset, @vertex_index_size, true); offset += @vertex_index_size
      @triangles[i + 2] = view.getBySize(offset, @vertex_index_size, true); offset += @vertex_index_size
    offset

  getTextures: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @textures =
      for i in [0...length]
        len = view.getUint32(offset, true)
        texture = view.getString(offset + size_Uint32, len, @utf8Encoding)
        offset += size_Uint32 + len * size_Uint8
        texture
    offset

  getMaterials: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @materials =
      for i in [0...length]
        material = new PMXMaterial(buffer, view, offset, this)
        offset += material.size
        material
    offset

  getBones: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @bones =
      for i in [0...length]
        bone = new PMXBone(buffer, view, offset, this)
        offset += bone.size
        bone
    offset

  getMorphs: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @morphs =
      for i in [0...length]
        morph = new PMXMorph(buffer, view, offset, this)
        offset += morph.size
        morph
    offset

  getFrames: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    @frames =
      for i in [0...length]
        frame = new PMXFrame(buffer, view, offset, this)
        offset += frame.size
        frame
    offset

  getRigidBodies: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32
    # console.log length
    @rigid_bodies =
      for i in [0...length]
        rigid_body = new PMXRigidBody(buffer, view, offset, this)
        offset += rigid_body.size
        rigid_body
    offset

  getJoints: (buffer, view, offset) ->
    length = view.getUint32(offset, true)
    offset += size_Uint32

    @joints =
      for i in [0...length]
        joint = new PMXJoint(buffer, view, offset, this)
        offset += joint.size
        joint
    offset

class PMXVertex
  # class constants
  @BDEF1: 0
  @BDEF2: 1
  @BDEF4: 2
  @SDEF:  3
  constructor: (buffer, view, offset, model) ->
    _offset = offset
    @x = view.getFloat32(offset, true); offset += size_Float32
    @y = view.getFloat32(offset, true); offset += size_Float32
    @z = -view.getFloat32(offset, true); offset += size_Float32 # left->right handed system
    @nx = view.getFloat32(offset, true); offset += size_Float32
    @ny = view.getFloat32(offset, true); offset += size_Float32
    @nz = -view.getFloat32(offset, true); offset += size_Float32 # left->right handed system
    @u = view.getFloat32(offset, true); offset += size_Float32
    @v = view.getFloat32(offset, true); offset += size_Float32
    @appendix_uv =
      for i in [0...model.appendix_uv]
        view.getFloat32(offset, true); offset += size_Float32
    @weight_type = view.getUint8(offset, true); offset += size_Uint8
    switch @weight_type
      when PMXVertex.BDEF1
        @bone_num1 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
      when PMXVertex.BDEF2
        @bone_num1 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_num2 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_weight1 = view.getFloat32(offset, true); offset += size_Float32
      when PMXVertex.BDEF4
        @bone_num1 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_num2 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_num3 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_num4 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_weight1 = view.getFloat32(offset, true); offset += size_Float32
        @bone_weight2 = view.getFloat32(offset, true); offset += size_Float32
        @bone_weight3 = view.getFloat32(offset, true); offset += size_Float32
        @bone_weight4 = view.getFloat32(offset, true); offset += size_Float32
      when PMXVertex.SDEF
        @bone_num1 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_num2 = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        @bone_weight1 = view.getFloat32(offset, true); offset += size_Float32
        @C = new Float32Array([
          view.getFloat32(offset, true),
          view.getFloat32(offset + size_Float32, true),
          view.getFloat32(offset + size_Float32 * 2, true)
        ]); offset += 3 * size_Float32
        @R0 = new Float32Array([
          view.getFloat32(offset, true),
          view.getFloat32(offset + size_Float32, true),
          view.getFloat32(offset + size_Float32 * 2, true)
        ]); offset += 3 * size_Float32
        @R1 = new Float32Array([
          view.getFloat32(offset, true),
          view.getFloat32(offset + size_Float32, true),
          view.getFloat32(offset + size_Float32 * 2, true)
        ]); offset += 3 * size_Float32
      else
        throw "Vertex weight_typpe format error: #{@weight_type}"
    @edge_scale = view.getFloat32(offset, true); offset += size_Float32
    @size = offset - _offset

class PMXMaterial
  constructor: (buffer, view, offset, model) ->
    _offset = offset

    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @name

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @english_name

    # diffuse RGBA
    @diffuse = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    @alpha = view.getFloat32(offset, true); offset += size_Float32

    # specular RGB
    @specular = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    @shininess = view.getFloat32(offset, true); offset += size_Float32

    # ambient RGB
    @ambient = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # drawing mode flag
    # 0x01 = Double-Sided, 0x02 = Shadow, 0x04 = Self shadow map, 0x08 = Self shadow, 0x10 = Draw edges
    @bit_flag = view.getUint8(offset); offset += size_Uint8

    # edge color RGBA
    @edge_color = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true),
      view.getFloat32(offset + size_Float32 * 3, true)
    ]); offset += 4 * size_Float32
    @edge_size = view.getFloat32(offset, true); offset += size_Float32

    # texture id
    @texture_index = view.getBySize(offset, model.texture_index_size, true); offset += model.texture_index_size
    @texture_file_name = model.textures[@texture_index]

    # sphere texture id
    # 0:void 1:sph 2:spa 3:サブテクスチャ
    @sphere_index = view.getBySize(offset, model.texture_index_size, true); offset += model.texture_index_size
    @sphere_mode = view.getUint8(offset); offset += size_Uint8

    # toon
    # If Toon Flag is 0, then it has the type specified in the Texture Index Size header field.
    # If Toon Flag is 1, the size is 1 byte with a value from 0-9.
    @toon_flag = view.getUint8(offset); offset += size_Uint8
    if Boolean(@toon_flag)
      @toon = view.getUint8(offset); offset += size_Uint8
    else
      @toon = view.getBySize(offset, model.material_index_size, true); offset += model.material_index_size

    len = view.getUint32(offset, true)
    @memo = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @memo

    # from face number, 3 times the face number
    @refs_vertex = view.getUint32(offset, true)
    offset += size_Uint32

    @size = offset - _offset

class PMXBone
  constructor: (buffer, view, offset, model) ->
    _offset = offset
    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log "name #{@name}"

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log "english name: #{@english_name}"

    # position
    @position = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    # console.log @position

    @parent_bone_index = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
    @morph_bone_index = view.getInt32(offset, true); offset += size_Uint32

    # console.log "parent: #{@parent_bone_index}"
    # console.log "morph: #{@morph_bone_index}"

    # 0x0001: 接続先(PMD子ボーン指定)表示方法 -> 0:座標オフセットで指定 1:ボーンで指定
    # 0x0002: 回転可能
    # 0x0004: 移動可能
    # 0x0008: 表示
    # 0x0010: 操作可
    # 0x0020: IK
    # 0x0080: ローカル付与 | 付与対象 0:ユーザー変形値／IKリンク／多重付与 1:親のローカル変形量
    # 0x0100: 回転付与
    # 0x0200: 移動付与
    # 0x0400: 軸固定
    # 0x0800: ローカル軸
    # 0x1000: 物理後変形
    # 0x2000: 外部親変形
    @bit_flag = view.getUint16(offset, true); offset += size_Uint16
    # console.log @bit_flag
    if @bit_flag & 0x1
      @connect_index = view.getBySize(offset, model.bone_index_size); offset += model.bone_index_size
    else
      @offset = new Float32Array([
        view.getFloat32(offset, true),
        view.getFloat32(offset + size_Float32, true),
        view.getFloat32(offset + size_Float32 * 2, true)
      ]); offset += 3 * size_Float32
      # console.log @offset

    if @bit_flag & 0x0300
      @inverse_parent_index = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
      @inverse_rate = view.getFloat32(offset, true); offset += size_Float32

    if @bit_flag & 0x0400
      @axis = new Float32Array([
        view.getFloat32(offset, true),
        view.getFloat32(offset + size_Float32, true),
        view.getFloat32(offset + size_Float32 * 2, true)
      ]); offset += 3 * size_Float32

    if @bit_flag & 0x0800
      @x_axis = new Float32Array([
        view.getFloat32(offset, true),
        view.getFloat32(offset + size_Float32, true),
        view.getFloat32(offset + size_Float32 * 2, true)
      ]); offset += 3 * size_Float32
      @z_axis = new Float32Array([
        view.getFloat32(offset, true),
        view.getFloat32(offset + size_Float32, true),
        view.getFloat32(offset + size_Float32 * 2, true)
      ]); offset += 3 * size_Float32

    if @bit_flag & 0x2000
      @parent_key = view.getInt32(offset, true); offset += size_Uint32
    
    if @bit_flag & 0x0020
      @ik_target_index = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
      @ik_loop_len = view.getUint32(offset, true); offset += size_Uint32
      # 4x
      @ik_rad_limited = view.getFloat32(offset, true); offset += size_Float32
      length = view.getUint32(offset, true); offset += size_Uint32
      @ik_links = []
      for i in [0...length]
        ik_link = {}
        ik_link['link_index'] = view.getBySize(offset, model.bone_index_size); offset += model.bone_index_size
        ik_link['rad_limited'] = view.getUint8(offset); offset += size_Uint8   # on/off
        if ik_link['rad_limited']
          ik_link['lower_vector'] = new Float32Array([
            view.getFloat32(offset, true),
            view.getFloat32(offset + size_Float32, true),
            view.getFloat32(offset + size_Float32 * 2, true)
          ]); offset += 3 * size_Float32
          ik_link['upper_vector'] = new Float32Array([
            view.getFloat32(offset, true),
            view.getFloat32(offset + size_Float32, true),
            view.getFloat32(offset + size_Float32 * 2, true)
          ]); offset += 3 * size_Float32
        @ik_links.push(ik_link)

    @size = offset - _offset

class PMXMorph
  constructor: (buffer, view, offset, model) ->
    _offset = offset

    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @name

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @english_name

    # 1:眉(左下) 2:目(左上) 3:口(右上) 4:その他(右下) | 0:system
    @panel = view.getUint8(offset); offset += size_Uint8
    # 0:group, 1:vertex, 2:bone, 3:UV, 4:appendix UV1, 5:appendix UV2, 6:appendix UV3, 7:appendix UV4, 8:material
    @type = view.getUint8(offset); offset += size_Uint8

    length = view.getUint32(offset, true); offset += size_Uint32
    @offset =
      for i in [0...length]
        data = {}
        switch @type
          when 0
            data.morph_index = view.getBySize(offset, model.morph_index_size); offset += model.morph_index_size
            data.morph_rate = view.getFloat32(offset, true); offset += size_Float32
          when 1
            data.vertex_index = view.getBySize(offset, model.vertex_index_size); offset += model.vertex_index_size
            data.coordinate = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
            ]); offset += 3 * size_Float32
          when 2
            data.bone_index = view.getBySize(offset, model.bone_index_size); offset += model.bone_index_size
            data.distance = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
            ]); offset += 3 * size_Float32
            data.turning = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32
          when 3, 4, 5, 6, 7
            data.vertex_index = view.getBySize(offset, model.vertex_index_size); offset += model.vertex_index_size
            data.uv_offset = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32
          when 8
            # material index -> -1: all material
            data.material_index = view.getBySize(offset, model.material_index_size); offset += model.material_index_size
            # offset type 0:乗算, 1:加算
            data.offset_type = view.getUint8(offset); offset += size_Uint8

            # diffuse RGBA
            data.diffuse = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
            ]); offset += 3 * size_Float32
            data.alpha = view.getFloat32(offset, true); offset += size_Float32

            # specular RGB
            data.specular = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
            ]); offset += 3 * size_Float32
            data.shininess = view.getFloat32(offset, true); offset += size_Float32

            # ambient RGB
            data.ambient = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true)
            ]); offset += 3 * size_Float32

            # edge color RGBA
            data.edge_color = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true),
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32
            data.edge_size = view.getFloat32(offset, true); offset += size_Float32

            # texture mod
            data.texture_mod = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true),
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32

            # sphere mod
            data.sphere_mod = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true),
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32

            # toon mod
            data.toon_mod = new Float32Array([
              view.getFloat32(offset, true),
              view.getFloat32(offset + size_Float32, true),
              view.getFloat32(offset + size_Float32 * 2, true),
              view.getFloat32(offset + size_Float32 * 3, true)
            ]); offset += 4 * size_Float32
        data

    @size = offset - _offset

class PMXFrame
  constructor: (buffer, view, offset, model) ->
    _offset = offset

    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @name

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @english_name

    # 0:regular frame 1:key frame
    @flag = view.getUint8(offset); offset += size_Uint8

    length = view.getUint32(offset, true); offset += size_Uint32
    @frames =
      for i in [0...length]
        data = {}
        data.type = view.getUint8(offset); offset += size_Uint8
        if data.type
          data.morph_index = view.getBySize(offset, model.morph_index_size, true); offset += model.morph_index_size
        else
          data.bone_index = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
        data

    @size = offset - _offset

class PMXRigidBody
  constructor: (buffer, view, offset, model) ->
    _offset = offset

    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @name

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @english_name

    @bone_index = view.getBySize(offset, model.bone_index_size, true); offset += model.bone_index_size
    @group = view.getUint8(offset); offset += size_Uint8
    # 2: ushort	| 非衝突グループフラグ
    @nocollision_group = view.getUint16(offset, true); offset += size_Uint16
    # 1: byte	| 形状 - 0:球 1:箱 2:カプセル
    @figure = view.getUint8(offset); offset += size_Uint8
    # float3	| size(x,y,z)
    @figure_size = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    # position (x,y,z)
    @position = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    # rad (x,y,z) -> ラジアン角, this seems to be incorrect
    @rad = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    # console.log @rad

    # mass
    @mass = view.getFloat32(offset, true); offset += size_Float32
    # moving attenuation
    @moving_attenuation = view.getFloat32(offset, true); offset += size_Float32
    # rad attenuation
    @rad_attenuation = view.getFloat32(offset, true); offset += size_Float32
    # bouncing force
    @bounce_force = view.getFloat32(offset, true); offset += size_Float32
    # friction
    @frictical_force = view.getFloat32(offset, true); offset += size_Float32
    # mode  0:ボーン追従(static) 1:物理演算(dynamic) 2:物理演算 + Bone位置合わせ
    @mode = view.getUint8(offset); offset += size_Uint8

    @size = offset - _offset

class PMXJoint
  constructor: (buffer, view, offset, model) ->
    _offset = offset

    len = view.getUint32(offset, true)
    @name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @name

    len = view.getUint32(offset, true)
    @english_name = view.getString(offset + size_Uint32, len, model.utf8Encoding)
    offset += size_Uint32 + size_Uint8 * len
    # console.log @english_name

    @type = view.getUint8(offset); offset += size_Uint8
    if @type then throw "PMX2.0 not supported"

    @rigid_index_a = view.getUint8(offset); offset += size_Uint8
    @rigid_index_b= view.getUint8(offset); offset += size_Uint8

    # position (x,y,z)
    @position = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    # rad (x,y,z) -> ラジアン角, this seems to be incorrect
    @rad = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # position lower vector (x,y,z)
    @position_lower_vector = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # position upper vector (x,y,z)
    @position_upper_vector = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # rad lower vector (x,y,z)
    @rad_lower_vector = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # rad upper vector (x,y,z)
    @rad_upper_vector = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # bounce moving (x,y,z)
    @bounce_moving = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32

    # bounce rad (x,y,z)
    @bounce_rad = new Float32Array([
      view.getFloat32(offset, true),
      view.getFloat32(offset + size_Float32, true),
      view.getFloat32(offset + size_Float32 * 2, true)
    ]); offset += 3 * size_Float32
    
    @size = offset - _offset
