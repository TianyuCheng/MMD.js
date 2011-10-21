class MMD.MotionManager
  constructor: ->
    @bones = {}
    @morphs = {}
    @morphFrames = {}
    @camera = null
    @cameraFrames = null
    @light = null
    @lightFrames = null
    @lastFrame = 0
    return

  addMotion: (motion) ->
    @addMorphMotion(motion)
    @addCameraMotoin(motion)
    @addLightMotoin(motion)

  addMorphMotion: (motion) ->
    for m in motion.morph
      continue if m.name == 'base'
      @morphs[m.name] = [0] if !@morphs[m.name] # set 0th frame as 0
      @morphs[m.name][m.frame] = m.weight
      @lastFrame = m.frame if @lastFrame < m.frame

    for name of @morphs
      @morphFrames[name] = Object.keys(@morphs[name]).map(Number).sort((a,b) -> a - b)

    return

  addCameraMotoin: (motion) ->
    return if motion.camera.length == 0
    @camera = []
    frames = []
    for c in motion.camera
      @camera[c.frame] = c
      frames.push(c.frame)
      @lastFrame = c.frame if @lastFrame < c.frame
    @cameraFrames = frames.sort((a, b) -> a - b)
    return

  addLightMotoin: (motion) ->
    return if motion.light.length == 0
    @light = []
    frames = []
    for l in motion.light
      @light[l.frame] = l
      frames.push(l.frame)
      @lastFrame = l.frame if @lastFrame < l.frame
    @lightFrames = frames.sort((a, b) -> a - b)
    return

  getFrame: (frame) ->
    return {
      morphs: @getMorphFrame(frame)
      camera: @getCameraFrame(frame)
      light: @getLightFrame(frame)
    }

  getMorphFrame: (frame) ->
    morphs = {}

    for name of @morphs
      timeline = @morphs[name]
      frames = @morphFrames[name]
      lastFrame = frames[frames.length - 1]
      if lastFrame <= frame
        morphs[name] = timeline[lastFrame]
      else
        idx = previousRegisteredFrame(frames, frame)
        p = frames[idx]
        n = frames[idx + 1]
        morphs[name] = interpolateLinear(p, n, timeline[p], timeline[n], frame)

    return morphs

  getCameraFrame: (frame) ->
    return null if not @camera
    timeline = @camera
    frames = @cameraFrames
    lastFrame = frames[frames.length - 1]
    if lastFrame <= frame
      camera = timeline[lastFrame]
    else
      idx = previousRegisteredFrame(frames, frame)
      p = frames[idx]
      n = frames[idx + 1]
      prev = timeline[p] # previous registered frame
      next = timeline[n] # next registered frame

      cache = []
      interpolated_x = (i)->
        [X1, X2, Y1, Y2] = Array.prototype.slice.call(next.interpolation, i * 4, i * 4 + 4)
        id = X1 | (X2 << 8) | (Y1 << 16) | (Y2 << 24)
        return cache[id] if cache[id]?
        return cache[id] = frame if X1 == Y1 and X2 == Y2
        a = interpolateBezier(X1 / 127, X2 / 127, Y1 / 127, Y2 / 127, (frame - p) / (n - p))
        return cache[id] = p + (n - p) * a

      camera = {
        location: [
          interpolateLinear(p, n, prev.location[0], next.location[0], interpolated_x(0))
          interpolateLinear(p, n, prev.location[1], next.location[1], interpolated_x(1))
          interpolateLinear(p, n, prev.location[2], next.location[2], interpolated_x(2))
        ]
        rotation: [
          interpolateLinear(p, n, prev.rotation[0], next.rotation[0], interpolated_x(3))
          interpolateLinear(p, n, prev.rotation[1], next.rotation[1], interpolated_x(3))
          interpolateLinear(p, n, prev.rotation[2], next.rotation[2], interpolated_x(3))
        ]
        distance: interpolateLinear(p, n, prev.distance, next.distance, interpolated_x(4))
        view_angle: interpolateLinear(p, n, prev.view_angle, next.view_angle, interpolated_x(5))
      }

    return camera

  getLightFrame: (frame) ->
    return null if not @light
    timeline = @light
    frames = @lightFrames
    lastFrame = frames[frames.length - 1]
    if lastFrame <= frame
      light = timeline[lastFrame]
    else
      idx = previousRegisteredFrame(frames, frame)
      p = frames[idx]
      n = frames[idx + 1]
      light = {
        color: [
          interpolateLinear(p, n, timeline[p].color[0], timeline[n].color[0], frame)
          interpolateLinear(p, n, timeline[p].color[1], timeline[n].color[1], frame)
          interpolateLinear(p, n, timeline[p].color[2], timeline[n].color[2], frame)
        ]
        location: [
          interpolateLinear(p, n, timeline[p].location[0], timeline[n].location[0], frame)
          interpolateLinear(p, n, timeline[p].location[1], timeline[n].location[1], frame)
          interpolateLinear(p, n, timeline[p].location[2], timeline[n].location[2], frame)
        ]
      }

    return light

# utils
previousRegisteredFrame = (frames, frame) ->
  ###
    'frames' is key frames registered, 'frame' is the key frame I'm enquiring about
    ex. frames: [0,10,20,30,40,50], frame: 15
    now I want to find the numbers 10 and 20, namely the ones before 15 and after 15
    I'm doing a bisection search here.
  ###
  idx = 0
  delta = frames.length
  while true
    delta = (delta >> 1) || 1
    if frames[idx] <= frame
      break if delta == 1 and frames[idx + 1] > frame
      idx += delta
    else
      idx -= delta
      break if delta == 1 and frames[idx] <= frame
  return idx

interpolateLinear = (x1, x2, y1, y2, x) ->
  # when using this function, make sure x1 < x2
  return (y2 * (x - x1) + y1 * (x2 - x)) / (x2 - x1)

interpolateBezier = (x1, x2, y1, y2, x) ->
  ###
    interpolate using Bezier curve (http://musashi.or.tv/fontguide_doc3.htm)
    Bezier curve is parametrized by t (0 <= t <= 1)
      x = s^3 x_0 + 3 s^2 t x_1 + 3 s t^2 x_2 + t^3 x_3
      y = s^3 y_0 + 3 s^2 t y_1 + 3 s t^2 y_2 + t^3 y_3
    where s is defined as s = 1 - t.
    Especially, for MMD, (x_0, y_0) = (0, 0) and (x_3, y_3) = (1, 1), so
      x = 3 s^2 t x_1 + 3 s t^2 x_2 + t^3
      y = 3 s^2 t y_1 + 3 s t^2 y_2 + t^3
    Now, given x, find t by bisection method (http://en.wikipedia.org/wiki/Bisection_method)
    i.e. find t such that f(t) = 3 s^2 t x_1 + 3 s t^2 x_2 + t^3 - x = 0
    One thing to note here is that f(t) is monotonically increasing in the range [0,1]
    Therefore, when I calculate f(t) for the t I guessed,
    Finally find y for the t.
  ###
  #Adopted from MMDAgent
  t = x
  while true
    v = ipfunc(t, x1, x2) - x
    break if v * v < 0.0000001 # Math.abs(v) < 0.0001
    tt = ipfuncd(t, x1, x2)
    break if tt == 0
    t -= v / tt
  return ipfunc(t, y1, y2)

ipfunc = (t, p1, p2) ->
  ((1 + 3 * p1 - 3 * p2) * t * t * t + (3 * p2 - 6 * p1) * t * t + 3 * p1 * t)

ipfuncd = (t, p1, p2) ->
  ((3 + 9 * p1 - 9 * p2) * t * t + (6 * p2 - 12 * p1) * t + 3 * p1)
