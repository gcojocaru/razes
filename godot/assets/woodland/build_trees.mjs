// node build_trees.mjs /path/to/ez-tree (npm install && npm run build:lib there first)
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL, fileURLToPath} from 'node:url';
const source = path.resolve(process.argv[2]);
const {Tree} = await import(pathToFileURL(path.join(source, 'build/ez-tree.es.js')));
const output = path.dirname(fileURLToPath(import.meta.url));
for (const [variant, seed, height] of [[0, 1523, 7.5], [1, 9821, 9]]) {
  const tree = new Tree();
  tree.loadPreset('Ash Medium');
  tree.options.seed = seed;
  tree.options.leaves.count = 10;
  tree.generate();
  const geometry = tree.createGeometry({sectionStride:2, segmentFactor:0.75, leafStride:2, leafScale:1.8});
  const meshes = [geometry.branches, geometry.leaves];
  const highest = Math.max(...meshes.flatMap(g => Array.from(g.attributes.position.array).filter((v,i)=>i%3===1)));
  const scale = height / highest;
  const chunks = [], views = [], accessors = [];
  let length = 0, triangles = 0;
  const add = (array, type, componentType, bounds=false) => {
    while (length % 4) { chunks.push(Buffer.alloc(1)); length++; }
    const raw = Buffer.from(array.buffer, array.byteOffset, array.byteLength);
    const view = views.length;
    views.push({buffer:0, byteOffset:length, byteLength:raw.length});
    chunks.push(raw); length += raw.length;
    const components = type==='SCALAR'?1:type==='VEC2'?2:3;
    const accessor = {bufferView:view, componentType, count:array.length/components, type};
    if (bounds) {
      accessor.min=[Infinity,Infinity,Infinity]; accessor.max=[-Infinity,-Infinity,-Infinity];
      for(let i=0;i<array.length;i++) { const c=i%3; accessor.min[c]=Math.min(accessor.min[c],array[i]); accessor.max[c]=Math.max(accessor.max[c],array[i]); }
    }
    accessors.push(accessor); return accessors.length-1;
  };
  const gltfMeshes = meshes.map((g, material) => {
    const positions = new Float32Array(g.attributes.position.array);
    for(let i=0;i<positions.length;i++) positions[i]*=scale;
    const indices = new Uint32Array(g.index.array);
    triangles += indices.length/3;
    return {name:material?'Leaves':'Trunk', primitives:[{attributes:{POSITION:add(positions,'VEC3',5126,true), NORMAL:add(g.attributes.normal.array,'VEC3',5126), TEXCOORD_0:add(g.attributes.uv.array,'VEC2',5126)},indices:add(indices,'SCALAR',5125),material}]};
  });
  assert(triangles<20000 && height>6 && height<10);
  while(length%4){chunks.push(Buffer.alloc(1)); length++;}
  const document={asset:{version:'2.0',generator:'EZ-Tree 1.1.0, static Ash Medium export'},scene:0,scenes:[{nodes:[0,1]}],nodes:[{name:'Trunk',mesh:0},{name:'Leaves',mesh:1}],meshes:gltfMeshes,accessors,bufferViews:views,buffers:[{byteLength:length}],images:[{uri:'bark.jpg'},{uri:'ash.png'}],samplers:[{magFilter:9729,minFilter:9987,wrapS:10497,wrapT:10497}],textures:[{sampler:0,source:0},{sampler:0,source:1}],materials:[{name:'Bark',pbrMetallicRoughness:{baseColorTexture:{index:0},metallicFactor:0,roughnessFactor:1}},{name:'Foliage',doubleSided:true,alphaMode:'MASK',alphaCutoff:0.5,pbrMetallicRoughness:{baseColorTexture:{index:1},metallicFactor:0,roughnessFactor:1}}]};
  let json=Buffer.from(JSON.stringify(document)); while(json.length%4)json=Buffer.concat([json,Buffer.from(' ')]);
  const binary=Buffer.concat(chunks), header=Buffer.alloc(12), jh=Buffer.alloc(8), bh=Buffer.alloc(8);
  header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(28+json.length+binary.length,8);
  jh.writeUInt32LE(json.length);jh.writeUInt32LE(0x4e4f534a,4);bh.writeUInt32LE(binary.length);bh.writeUInt32LE(0x004e4942,4);
  fs.writeFileSync(path.join(output,`ash_${variant}.glb`),Buffer.concat([header,jh,json,bh,binary]));
  console.log(`ash_${variant}.glb: ${triangles} triangles, ${height}m`);
}
