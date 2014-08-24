MMD.PMXFragmentShaderSource = '''

  #ifdef GL_ES
  precision highp float;
  #endif
   
  varying vec2 vTextureCoord;
  varying vec3 vPosition;
  varying vec3 vNormal;
  // varying vec4 vLightCoord;

  uniform vec3 uLightDirection; // light source direction in world space
  uniform vec3 uLightColor;

  uniform vec3 uAmbientColor;
  uniform vec3 uSpecularColor;
  uniform vec3 uDiffuseColor;
  uniform float uAlpha;
  uniform float uShininess;

  uniform bool uUseTexture;
  uniform bool uUseSphereMap;
  uniform bool uIsSphereMapAdditive;

  uniform sampler2D uToon;
  uniform sampler2D uTexture;
  uniform sampler2D uSphereMap;

  void main() {
    vec3 color;
    float alpha = uAlpha;

    // vectors are in view space
    vec3 norm = normalize(vNormal); // each point's normal vector in view space
    vec3 cameraDirection = normalize(-vPosition); // camera located at origin in view space

    color = vec3(1.0, 1.0, 1.0);
    if (uUseTexture) {
      vec4 texColor = texture2D(uTexture, vTextureCoord);
      color *= texColor.rgb;
      alpha *= texColor.a;
    }

    if (uUseSphereMap) {
      vec2 sphereCoord = 0.5 * (1.0 + vec2(1.0, -1.0) * norm.xy);
      if (uIsSphereMapAdditive) {
        color += texture2D(uSphereMap, sphereCoord).rgb;
      } else {
        color *= texture2D(uSphereMap, sphereCoord).rgb;
      }
    }

    // specular component
    // vec3 halfAngle = normalize(uLightDirection/* + cameraDirection*/);
    // float specularWeight = pow( max(0.001, dot(halfAngle, norm)) , uShininess );
    // //float specularWeight = pow( max(0.0, dot(reflect(-uLightDirection, norm), cameraDirection)) , uShininess ); // another definition
    // vec3 specular = specularWeight * uSpecularColor;

    // vec2 toonCoord = vec2(0.0, 0.5 * (1.0 - dot( uLightDirection, norm )));

    color *= uAmbientColor + uLightColor * (uDiffuseColor/* + specular*/);
    color = clamp(color, 0.0, 1.0);

    gl_FragColor = vec4(color, alpha);
  }

'''
