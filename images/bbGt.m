function varargout = bbGt( action, varargin )
% Data structure for bounding box (bb) image annotations.
%
% The bounding box annotation stores bounding boxes for objects of interest
% with additional information per object, such as occlusion information.
% The underlying data structure is simply a Matlab stuct array, one struct
% per object. This annotation format is an alternative to the annotation
% format used for the PASCAL object challenges.
%
% Each object struct has the following fields:
%  lbl  - a string label describing object type (eg: 'pedestrian')
%  bb   - [l t w h]: bb indicating predicted object extent
%  occ  - 0/1 value indicating if bb is occluded
%  bbv  - [l t w h]: bb indicating visible region (may be [0 0 0 0])
%  ign  - 0/1 value indicating bb was marked as ignore
%
% bbGt contains a number of utility functions, accessed using:
%  outputs = bbGt( 'action', inputs );
% The list of functions and help for each is given below. Also, help on
% individual subfunctions can be accessed by: "help bbGt>action".
%
% Create annotation of n empty objects.
%   objs = bbGt( 'create', [n] );
% Save bb annotation to text file.
%   objs = bbGt( 'bbSave', objs, fName )
% Load bb annotation from text file.
%   objs = bbGt( 'bbLoad', fName )
% Returns the ground truth bbs for purpose of evaluation.
%   gtBbs = bbGt( 'toGt', objs, lbls, prm )
% Sample pos or neg examples for training from an annotated image.
%   [bbs, patches] = bbGt( 'sampleData', I, prm )
%
% USAGE
%  varargout = bbGt( action, varargin );
%
% INPUTS
%  action     - string specifying action
%  varargin   - depends on action, see above
%
% OUTPUTS
%  varargout  - depends on action, see above
%
% EXAMPLE
%
% See also bbApply, bbGt>create, bbGt>bbSave, bbGt>bbLoad, bbGt>toGt,
% bbGt>sampleData
%
% Piotr's Image&Video Toolbox      Version NEW
% Copyright 2009 Piotr Dollar.  [pdollar-at-caltech.edu]
% Please email me if you find bugs, or have suggestions or questions!
% Licensed under the Lesser GPL [see external/lgpl.txt]

%#ok<*DEFNU>
varargout = cell(1,max(1,nargout));
[varargout{:}] = feval(action,varargin{:});
end

function objs = create( n )
% Create annotation of n empty objects.
%
% USAGE
%  objs = bbGt( 'create', [n] )
%
% INPUTS
%  n      - [1] number of objects to create
%
% OUTPUTS
%  objs   - annotation of n 'empty' objects
%
% EXAMPLE
%  objs = bbGt('create')
%
% See also bbGt
objs=struct('lbl','','bb',[0 0 0 0],'occ',0,'bbv',[0 0 0 0],'ign',0);
if(nargin<1), n=1; end; if(n~=1), objs=repmat(objs,n,1); end
end

function objs = bbSave( objs, fName )
% Save bb annotation to text file.
%
% USAGE
%  objs = bbGt( 'bbSave', objs, fName )
%
% INPUTS
%  objs   - objects to save
%  fName  - name of text file
%
% OUTPUTS
%  objs   - objects to save
%
% EXAMPLE
%
% See also bbGt, bbGt>bbLoad
vers=2; fid=fopen(fName,'w'); assert(fid>0);
fprintf(fid,'%% bbGt version=%i\n',vers);
for i=1:length(objs)
  o=objs(i); bb=o.bb; bbv=o.bbv;
  fprintf(fid,'%s %i %i %i %i %i %i %i %i %i %i\n',o.lbl,...
    bb(1),bb(2),bb(3),bb(4),o.occ,bbv(1),bbv(2),bbv(3),bbv(4),o.ign);
end
fclose(fid);
end

function objs = bbLoad( fName )
% Load bb annotation from text file.
%
% USAGE
%  objs = bbGt( 'bbLoad', fName )
%
% INPUTS
%  fName  - name of text file
%
% OUTPUTS
%  objs   - loaded objects
%
% EXAMPLE
%
% See also bbGt, bbGt>bbSave
if(~exist(fName,'file')), error([fName ' not found']); end
try v=textread(fName,'%% bbGt version=%d',1); catch, v=0; end %#ok<CTCH>
if(isempty(v)), v=0; end; opts={'commentstyle','matlab'};
switch v
  case {0,1}
    in=cell(1,10);
    [in{:}]=textread(fName,['%s' repmat(' %d',1,9)],opts{:});
    in{11} = zeros(length(in{1}),1);
  case 2
    in=cell(1,11);
    [in{:}]=textread(fName,['%s' repmat(' %d',1,10)],opts{:});
  otherwise, error('Unknown version %i.',v);
end
nObj=length(in{1}); O=ones(1,nObj); occ=mat2cell(in{6},O,1);
bb=mat2cell([in{2:5}],O,4); bbv=mat2cell([in{7:10}],O,4);
ign=mat2cell(in{11},O,1);
objs=struct('lbl',in{1},'bb',bb,'occ',occ,'bbv',bbv,'ign',ign);
end

function [gtBbs,ids] = toGt( objs, lbls, prm )
% Returns the ground truth bbs for purpose of evaluation.
%
% Returns bbs for all objects with lbl in lbls. The result is an [nx5]
% array where each row is of the form [x y w h ignore]. [x y w h] is the bb
% and ignore is a 0/1 flag that indicates regions to be ignored. For each
% returned object, the ignore flag is set to 1 if obj.ign==1 or any object
% property is outside of the specified range (details below). The ignore
% flag is used during evaluation so that objects with certain properties
% (such as very small or heavily occluded objects) can be excluded.
%
% The range for each property is a two element vector, [0 inf] by default,
% and a property value v is inside the range if v>=rng(1) && v<=rng(2).
% Tested properties include the height (h), width (w), area (a), aspect
% ratio (ar), and fraction visible (v). The last property is computed as
% the visible object area divided by the total area, except if o.occ==0, in
% which case v=1, or all(o.bbv==o.bb), which indicates the object may be
% barely visible, in which case v=0.
%
% USAGE
%  gtBbs = bbGt( 'toGt', objs, lbls, prm )
%
% INPUTS
%  objs     - ground truth objects
%  lbls     - string or cell array of string labels
%  prm      -
%   .hRng       - [0 inf] range of acceptable obj heights
%   .wRng       - [0 inf] range of acceptable obj widths
%   .aRng       - [0 inf] range of acceptable obj areas
%   .arRng      - [0 inf] range of acceptable obj aspect ratios
%   .vRng       - [0 inf] range of acceptable obj occlusion levels
%
% OUTPUTS
%  gtBbs    - [n x 5] array containg ground truth bbs [x y w h ignore]
%  ids      - [n x 1] list of object ids selected
%
% EXAMPLE
%  objs=bbGt('create',3);
%  objs(1).ign=0; objs(1).lbl='person'; objs(1).bb=[0 0 10 10];
%  objs(2).ign=0; objs(2).lbl='person'; objs(2).bb=[0 0 20 20];
%  objs(3).ign=0; objs(3).lbl='bicycle'; objs(3).bb=[0 0 20 20];
%  [gtBbs,ids] = bbGt( 'toGt', objs, 'person', {'hRng',[15 inf]} )
%
% See also bbGt

r=[0 inf]; dfs={'hRng',r,'wRng',r,'aRng',r,'arRng',r,'vRng',r};
[hRng,wRng,aRng,arRng,vRng] = getPrmDflt( prm, dfs, 1 );
nObj=length(objs); keep=true(nObj,1); gtBbs=zeros(nObj,5);
check = @(v,rng) v<rng(1) || v>rng(2);
for i=1:nObj, o=objs(i);
  if(~any(strcmp(o.lbl,lbls))), keep(i)=0; continue; end
  bb=o.bb; bbv=o.bbv; w=bb(3); h=bb(4); a=w*h; ar=w/h;
  if(~o.occ || all(bbv==0)), v=1; elseif(all(bbv==bb)), v=0; else
    v=bbv(3)*bbv(4)/a;
  end
  ign = o.ign || check(h,hRng) || check(w,wRng) || ...
    check(a,aRng) || check(ar,arRng) || check(v,vRng );
  gtBbs(i,1:4)=o.bb; gtBbs(i,5)=ign;
end
ids=find(keep); gtBbs=gtBbs(keep,:);
end

function [bbs, patches] = sampleData( I, prm )
% Sample pos or neg examples for training from an annotated image.
%
% An annotated image can contain both pos and neg examples of a given class
% (such as a pedestrian). This function allows for sampling of only pos
% windows, without sampling any negs, or vice-versa. For example, this can
% be quite useful during bootstrapping, to sample high scoring false pos
% without actually sampling any windows that contain true pos.
%
% bbs should contain the candidate bounding boxes, and ibbs should contain
% the bounding boxes that are to be ignored. During sampling, only bbs that
% do not match any ibbs are kept (two bbs match if their area of overlap is
% above the given thr, see bbEval>compOas). Use gtBbs=toGt(...) to obtain a
% list of ground truth bbs containing the positive windows. Let dtBbs
% contain the bbs output by some detection algorithm. Then,
%  to sample true-positives, use:   bbs=gtBbs and ibbs=[]
%  to sample false-negatives, use:  bbs=gtBbs and ibbs=dtBbs
%  to sample false-positives, use:  bbs=dtBbs and ibbs=gtBbs
% To sample regular negatives without bootstrapping generate bbs
% systematically or randomly (see for example bbApply>random).
%
% dims determines the dimension of the sampled bbs. If dims has two
% elements [w h], then the aspect ratio (ar) of each bb is set to ar=w/h
% using bbApply>squarify, and the extracted patches are resized to the
% target w and h. If dims has 1 element then ar=dims, but the bbs are not
% resized to a fixed size. If dims==[], the bbs are not altered.
%
% USAGE
%  [bbs, patches] = bbGt( 'sampleData', I, prm )
%
% INPUTS
%  I        - input image from which to sample
%  prm      -
%   .n          - [REQ] max number of bbs to sample
%   .bbs        - [REQ] candidate bbs from which to sample [x y w h ign]
%   .ibbs       - [] bbs that should not be sampled [x y w h ign]
%   .thr        - [.5] overlap threshold between bbs and ibbs
%   .dims       - [] target bb aspect ratio [ar] or dims [h w]
%   .pad        - [0] fraction extra padding for each sampled patch
%   .padEl      - ['replicate'] how to pad at boundaries (see bbApply>crop)
%
% OUTPUTS
%  bbs      - actual sampled bbs
%  patches  - [1xn] cell of cropped image regions
%
% EXAMPLE
%
% See also bbGt, bbGt>toGt, bbApply>crop, bbApply>resize, bbApply>squarify
% bbApply>random, bbEval>compOas

% get parameters
dfs={'n','REQ', 'bbs','REQ', 'ibbs',zeros(0,5), 'thr',.5, 'dims',[], ...
  'pad',0, 'padEl','replicate' };
[n,bbs,ibbs,thr,dims,pad,padEl] = getPrmDflt( prm, dfs, 1 );
if(numel(dims)==2), ar=dims(1)/dims(2); else ar=dims; dims=[]; end
% discard any candidate bbs that match the ignore bbs, sample to at most n
if(size(bbs,2)==5), bbs=bbs(bbs(:,5)==0,:); end
m=size(bbs,1); kp=true(1,m);
for i=1:m, kp(i)=all(bbEval('compOas',bbs(i,:),ibbs,ibbs(:,5))<thr); end
bbs=bbs(kp,:); m=sum(kp); if(m>n), bbs=bbs(randSample(m,n),:); end
% standardize aspect ratios (by growing bbs) and pad bbs
if(~isempty(ar)), bbs=bbApply('squarify',bbs,0,ar); end
if(pad~=0), bbs=bbApply('resize',bbs,(1+pad),(1+pad)); end
% crop patches, resizing if dims~=[]
if(nargout==2), [patches,bbs]=bbApply('crop',I,bbs,padEl,dims*(1+pad)); end

end