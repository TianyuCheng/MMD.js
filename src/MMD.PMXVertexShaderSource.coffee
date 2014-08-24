MMD.PMXVertexShaderSource = '''

  uniform mat4 uMVMatrix; // model-view matrix (model -> view space)
  uniform mat4 uPMatrix; // projection matrix (view -> projection space)
  uniform mat4 uNMatrix; // normal matrix (inverse of transpose of model-view matrix)

  attribute vec3 aVertexPosition;
  attribute vec3 aVertexNormal;
  attribute vec2 aTextureCoord;

  varying vec2 vTextureCoord;
  varying vec3 vPosition;
  varying vec3 vNormal;

  vec3 qtransform(vec4 q, vec3 v) {
    return v + 2.0 * cross(cross(v, q.xyz) - q.w*v, q.xyz);
  }

  void main() {
    vec3 position = aVertexPosition;
    vec3 normal = aVertexNormal;

    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);

    // for fragment shader
    vTextureCoord = aTextureCoord;
    vPosition = (uMVMatrix * vec4(position, 1.0)).xyz;
    vNormal = (uNMatrix * vec4(normal, 1.0)).xyz;
  }

'''
