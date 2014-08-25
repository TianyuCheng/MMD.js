MMD.PMXVertexShaderSource = '''

  precision mediump float;

  uniform mat4 uMVMatrix; // model-view matrix (model -> view space)
  uniform mat4 uPMatrix; // projection matrix (view -> projection space)
  uniform mat4 uNMatrix; // normal matrix (inverse of transpose of model-view matrix)

  attribute vec3 aVertexPosition;
  attribute vec3 aVertexNormal;
  attribute vec2 aTextureCoord;

  // for vertices
  attribute float aWeightType;   // 0=BDEF1 1=BDEF2 2=BDEF4 3=SDEF
  attribute vec4 aBoneWeights;
  // remove all aVectorFromBoneX due to the limit of VertexShader attributes
  attribute vec3 aBone1Position;
  attribute vec3 aBone2Position;
  attribute vec3 aBone3Position;
  attribute vec3 aBone4Position;
  attribute vec4 aBone1Rotation;
  attribute vec4 aBone2Rotation;
  attribute vec4 aBone3Rotation;
  attribute vec4 aBone4Rotation;
  attribute vec3 aMultiPurposeVector;

  varying vec2 vTextureCoord;
  varying vec3 vPosition;
  varying vec3 vNormal;

  vec3 qtransform(vec4 q, vec3 v) {
    return v + 2.0 * cross(cross(v, q.xyz) - q.w*v, q.xyz);
  }

  void main() {
    vec3 position;
    vec3 normal = aVertexNormal;
    vec3 morph = aMultiPurposeVector;

    // calculate vector from bones
    vec3 vectorFromBone1 = aVertexPosition - aBone1Position;
    vec3 vectorFromBone2 = aVertexPosition - aBone2Position;
    vec3 vectorFromBone3 = aVertexPosition - aBone3Position;
    vec3 vectorFromBone4 = aVertexPosition - aBone4Position;

    // check type of deformation
    int type = int(aWeightType);
    if (type == 0)            // BDEF1
    {
      position = qtransform(aBone1Rotation, vectorFromBone1 + morph) + aBone1Position;
    }
    else if (type == 1)       // BDEF2
    {
      vec3 p1 = qtransform(aBone1Rotation, vectorFromBone1 + morph) + aBone1Position;
      vec3 p2 = qtransform(aBone2Rotation, vectorFromBone2 + morph) + aBone2Position;
      position = mix(p2, p1, aBoneWeights[0]);
    }
    else if (type == 2)       // BDEF 4
    {
      vec3 p1 = qtransform(aBone1Rotation, vectorFromBone1 + morph) + aBone1Position;
      vec3 p2 = qtransform(aBone2Rotation, vectorFromBone2 + morph) + aBone2Position;
      vec3 p3 = qtransform(aBone3Rotation, vectorFromBone3 + morph) + aBone3Position;
      vec3 p4 = qtransform(aBone4Rotation, vectorFromBone4 + morph) + aBone4Position;
      position = p1 * aBoneWeights[0] + p2 * aBoneWeights[1] + p3 * aBoneWeights[2] + p4 * aBoneWeights[3];
    }
    else                      // SDEF 
    {
      // not implemented
      vec3 p1 = qtransform(aBone1Rotation, vectorFromBone1 + morph) + aBone1Position;
      vec3 p2 = qtransform(aBone2Rotation, vectorFromBone2 + morph) + aBone2Position;
      position = mix(p2, p1, aBoneWeights[0]);
    }

    gl_Position = uPMatrix * uMVMatrix * vec4(position, 1.0);

    // for fragment shader
    vTextureCoord = aTextureCoord;
    vPosition = (uMVMatrix * vec4(position, 1.0)).xyz;
    // vPosition = (uMVMatrix * vec4(aVertexPosition, 1.0)).xyz;
    vNormal = (uNMatrix * vec4(normal, 1.0)).xyz;
  }

'''
