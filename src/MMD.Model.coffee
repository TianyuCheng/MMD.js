# interface to create an instance of model
# according to the suffix

this.MMD.Model = (directory, filename) ->
  tmp = filename.toLowerCase()

  if (tmp.indexOf "pmd") isnt -1
    return new MMD.PMDModel(directory, filename)

  if (tmp.indexOf "pmx") isnt -1
    return new MMD.PMXModel(directory, filename)

  throw "Unknown model format!"

this.MMD.Renderer = (mmd, model) ->
  switch model.type
    when "PMD"
      return new MMD.PMDRenderer(mmd, model)
    when "PMX"
      return new MMD.PMXRenderer(mmd, model)
    else
      throw "No matching renderer for format #{model.type}!"
