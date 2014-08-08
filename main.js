window.onload = function() {
  var size = 512
  var canvas = document.createElement('canvas');
  canvas.width = size * 2;
  canvas.height = size;
  canvas.style.border = 'solid black 1px';

  document.body.appendChild(canvas);

  var mmd = new MMD(canvas, canvas.width, canvas.height);
  mmd.initShaders();
  mmd.initParameters();
  mmd.registerKeyListener(document);
  mmd.registerMouseListener(document);

  mmd.addModel("miku", new MMD.Model('model', 'Miku_Hatsune_Ver2.pmd'));
  mmd.addModel("rin", new MMD.Model('model', 'Rin_Kagamene_act2.pmd'));
  mmd.addModel("len", new MMD.Model('model', 'Len_Kagamine.pmd'));
  mmd.load(function() {
    var miku = mmd.getModelRenderer("miku");
    var rin  = mmd.getModelRenderer("rin");
    var len  = mmd.getModelRenderer("len");

    miku.rotate(0.0, 0.0, 1.0, 0.0);
    miku.translate(0.0, 0.0, 10.0);
    // miku.scale(2.0, 2.0, 2.0);

    rin.rotate(2.09, 0.0, 1.0, 0.0);
    rin.translate(0.0, 0.0, 10.0);
    // rin.scale(2.0, 2.0, 2.0);

    len.rotate(4.18, 0.0, 1.0, 0.0);
    len.translate(0.0, 0.0, 10.0);
    // len.scale(2.0, 2.0, 2.0);

    mmd.start();

    var dance = new MMD.Motion('motion/kishimen.vmd');
    dance.load(function() {
      mmd.addModelMotion("miku", dance, true);
      mmd.addModelMotion("rin", dance, true);
      mmd.addModelMotion("len", dance, true);
      mmd.play();

      setInterval(function() {
        // console.log('fps = ' + mmd.realFps);
      }, 1000);
    });
  })

  // miku.load(function() {
  //   mmd.addModel(miku);
  //   // mmd.initBuffers();
  //   mmd.start();
  //
  //   // var dance = new MMD.Motion('motion/kishimen.vmd');
  //   // dance.load(function() {
  //   //   mmd.addModelMotion(miku, dance, true);
  //   //
  //   //   mmd.play()
  //   //
  //   //   setInterval(function() {
  //   //     // console.log('fps = ' + mmd.realFps);
  //   //   }, 1000);
  //   // });
  // });
};
