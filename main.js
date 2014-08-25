window.onload = function() {
  var canvas = document.createElement('canvas');
  canvas.width = 720;
  canvas.height = 480;
  canvas.style.border = 'solid black 1px';

  document.body.appendChild(canvas);

  // testImage("model/Tda_Miku/body00_MikuAp.tga.png")

  var mmd = new MMD(canvas, canvas.width, canvas.height);
  mmd.registerKeyListener(document);
  mmd.registerMouseListener(document);

  // mmd.addModel("miku", new MMD.Model('model', 'Miku_Hatsune_metal.pmd'));
  // mmd.addModel("rin",  new MMD.Model('model', 'Rin_Kagamene_act2.pmd'));
  // mmd.addModel("len",  new MMD.Model('model', 'Len_Kagamine.pmd'));
  mmd.addModel("Tda_Miku", new MMD.Model('model/Tda_Miku', 'Tda_Miku.pmx'));

  // mmd.load(function() {
  //   var miku = mmd.getModelRenderer("miku");
  //   var rin  = mmd.getModelRenderer("rin");
  //   var len  = mmd.getModelRenderer("len");
  //
  //   miku.rotate(0.0, 0.0, 1.0, 0.0);
  //   miku.translate(0.0, 0.0, 10.0);
  //   // miku.scale(2.0, 2.0, 2.0);
  //
  //   rin.rotate(2.09, 0.0, 1.0, 0.0);
  //   rin.translate(0.0, 0.0, 10.0);
  //   // rin.scale(2.0, 2.0, 2.0);
  //
  //   len.rotate(4.18, 0.0, 1.0, 0.0);
  //   len.translate(0.0, 0.0, 10.0);
  //   // len.scale(2.0, 2.0, 2.0);
  //
  //   mmd.start();
  //
  //   var dance = new MMD.Motion('motion/kishimen.vmd');
  //   dance.load(function() {
  //     miku.addModelMotion("kishimen", dance, true);
  //     rin.addModelMotion("kishimen", dance, true);
  //     len.addModelMotion("kishimen", dance, true);
  //
  //     var mikudance = document.getElementById("dance");
  //     mikudance.onclick = function() {
  //       miku.play("kishimen");
  //       rin.play("kishimen");
  //       len.play("kishimen");
  //     }
  //   });
  //
  //   var arm = new MMD.Motion('motion/arm.vmd');
  //   arm.load(function() {
  //     miku.addModelMotion("arm", arm, true);
  //     rin.addModelMotion("arm", arm, true);
  //     len.addModelMotion("arm", arm, true);
  //
  //     var mikuarm = document.getElementById("arm");
  //     mikuarm.onclick = function() {
  //       miku.play("arm");
  //       rin.play("arm");
  //       len.play("arm");
  //     }
  //   });
  //
  //   mmd.play();
  //
  // })
  

  mmd.load(function() {
    var tda_miku = mmd.getModelRenderer("Tda_Miku");
    // var miku = mmd.getModelRenderer("miku");
    // miku.translate(0.0, 0.0, -10.0);

    mmd.start();
    mmd.play();

    // var kishimen = new MMD.Motion('motion/kishimen.vmd');
    // kishimen.load(function() {
    //   miku.addModelMotion("kishimen", kishimen, true);
    //
    //   var mikukishimen = document.getElementById("dance");
    //   mikukishimen.onclick = function() {
    //     miku.play("kishimen");
    //   }
    // });
    
    var motion = new MMD.Motion('motion/tda_miku.vmd');
    motion.load(function() {
      tda_miku.addModelMotion("motion", motion);
      tda_miku.play("motion");
    });

  });


};
