MMD.PMXVertexShaderSource = '''

  uniform mat4 uMVMatrix; // model-view matrix (model -> view space)
  uniform mat4 uPMatrix; // projection matrix (view -> projection space)
  uniform mat4 uNMatrix; // normal matrix (inverse of transpose of model-view matrix)

  uniform mat4 uLightMatrix; // mvpdMatrix of light space (model -> display space)

  attribute vec3 aVertexPosition;

  vec3 qtransform(vec4 q, vec3 v) {
    return v + 2.0 * cross(cross(v, q.xyz) - q.w*v, q.xyz);
  }

  void main() {
    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
  }

'''
