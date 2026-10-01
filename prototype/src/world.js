"use strict";
const World=(()=>{
 let renderer,scene,camera,cart,fxRenderer,fxScene,fxCamera,last=0,particles=[];
 const canvas=document.querySelector('#world');
 function mesh(geometry,color,x,y,z){const m=new THREE.Mesh(geometry,new THREE.MeshStandardMaterial({color,roughness:.85}));m.position.set(x,y,z);m.castShadow=true;m.receiveShadow=true;scene.add(m);return m;}
 try{
  renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  scene=new THREE.Scene();scene.fog=new THREE.Fog(0x233e48,18,36);camera=new THREE.PerspectiveCamera(38,1,.1,80);camera.position.set(11,13,17);camera.lookAt(0,0,0);
  scene.add(new THREE.HemisphereLight(0xd2f0ff,0x39472e,2.4));const sun=new THREE.DirectionalLight(0xffdfad,3);sun.position.set(-5,12,8);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-12;sun.shadow.camera.right=12;sun.shadow.camera.top=12;sun.shadow.camera.bottom=-12;scene.add(sun);
  mesh(new THREE.BoxGeometry(15,.7,12),0x526b51,0,-.5,0);mesh(new THREE.BoxGeometry(15,.09,1.3),0x4c9ba3,0,-.07,2.7);
  for(let i=0;i<32;i++){const x=-6+i*.39,z=Math.sin(i*.22)*1.5;mesh(new THREE.CylinderGeometry(.48,.48,.09,12),0xbda97a,x,-.02,z);}
  for(let i=0;i<25;i++){const x=Math.sin(i*15.4)*6.5,z=Math.cos(i*9.6)*5;if(Math.abs(z)<2)continue;mesh(new THREE.CylinderGeometry(.09,.14,1,6),0x70583d,x,.4,z);mesh(new THREE.ConeGeometry(.65,1.9,7),i%2?0x284f45:0x36614b,x,1.5,z);}
  for(const x of [-5.7,5.7]){mesh(new THREE.BoxGeometry(1.4,1.3,1.4),0xd7c5a0,x,.6,0);const roof=mesh(new THREE.ConeGeometry(1.25,.9,4),0x7e5c48,x,1.65,0);roof.rotation.y=Math.PI/4;}
  mesh(new THREE.CylinderGeometry(.45,.7,3.5,8),0xdbd3b3,5.7,1.6,-2);mesh(new THREE.ConeGeometry(.75,.7,8),0xb2784e,5.7,3.65,-2);
  cart=mesh(new THREE.BoxGeometry(.75,.6,.55),0xeac581,-5.6,.55,0);for(const z of [-.35,.35]){const wheel=new THREE.Mesh(new THREE.CylinderGeometry(.23,.23,.1,10),new THREE.MeshStandardMaterial({color:0x27363a}));wheel.rotation.x=Math.PI/2;wheel.position.set(0,-.25,z);cart.add(wheel);}
  fxRenderer=new THREE.WebGLRenderer({canvas:document.querySelector('#fx'),alpha:true,antialias:true});fxRenderer.setPixelRatio(Math.min(devicePixelRatio,2));fxScene=new THREE.Scene();fxCamera=new THREE.OrthographicCamera(0,innerWidth,0,innerHeight,-10,10);fxCamera.position.z=5;
  const animate=t=>{requestAnimationFrame(animate);const dt=Math.min((t-last)/1000,.05);last=t;
   if(!document.body.classList.contains('in-battle')){const w=canvas.clientWidth,h=canvas.clientHeight;if(w&&h){renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();cart.position.y=.55+Math.sin(t*.003)*.035;renderer.render(scene,camera);}}
   fxRenderer.setSize(innerWidth,innerHeight);fxCamera.right=innerWidth;fxCamera.bottom=innerHeight;fxCamera.updateProjectionMatrix();for(const p of particles){p.life-=dt;p.mesh.position.x+=p.vx*dt;p.mesh.position.y+=p.vy*dt;p.vy+=75*dt;p.mesh.material.opacity=Math.max(0,p.life);}particles=particles.filter(p=>{if(p.life>0)return true;fxScene.remove(p.mesh);p.mesh.geometry.dispose();p.mesh.material.dispose();return false;});fxRenderer.render(fxScene,fxCamera);
  };requestAnimationFrame(animate);
 }catch(e){document.querySelector('#webgl-note').textContent='3D表示を利用できません。依頼・戦闘はそのまま遊べます。';}
 function progress(stage){if(cart){cart.position.x=-5.6+stage*5.6;cart.position.z=Math.sin((cart.position.x+6)/.39*.22)*1.5;}}
 function burst(pos,heal=false){if(!fxScene)return;const cell=document.querySelector(`[data-pos="${pos}"]`);if(!cell)return;const r=cell.getBoundingClientRect();for(let i=0;i<24;i++){const m=new THREE.Mesh(new THREE.CircleGeometry(heal?3:2,6),new THREE.MeshBasicMaterial({color:heal?0x83ffe0:0xffc675,transparent:true,depthTest:false}));m.position.set(r.x+r.width/2,r.y+r.height/2,0);fxScene.add(m);const angle=Math.random()*Math.PI*2,speed=40+Math.random()*120;particles.push({mesh:m,vx:Math.cos(angle)*speed,vy:heal?-40-Math.random()*100:Math.sin(angle)*speed,life:.7+Math.random()*.4});}}
 return {progress,burst,ready:()=>!!renderer&&!!fxRenderer};
})();
