function [b0, dt, violMask] = dki_fit(dwi, grad, mask, constraints, outliers, maxbval)
% Diffusion Kurtosis Imaging tensor estimation using
% (constrained) weighted linear least squares estimation
% -----------------------------------------------------------------------------------
% please cite:  Veraart, J.; Sijbers, J.; Sunaert, S.; Leemans, A. & Jeurissen, B.,
%               Weighted linear least squares estimation of diffusion MRI parameters:
%               strengths, limitations, and pitfalls. NeuroImage, 2013, 81, 335-346
%------------------------------------------------------------------------------------
%
% Usage:
% ------
% [b0, dt] = dki_fit(dwi, grad [, mask [, constraints]])
%
% Required input:
% ---------------
%     1. dwi: diffusion-weighted images.
%           [x, y, z, ndwis]
%
%       Important: We recommend that you apply denoising, gibbs correction, motion-
%       and eddy current correction to the diffusion-weighted image
%       prior to tensor fitting. Thes steps are not includede in this
%       tools, but we are happy to assist (Jelle.Veraart@nyumc.org).
%
%     2. grad: diffusion encoding information (gradient direction 'g = [gx, gy, gz]' and b-values 'b')
%           [ndwis, 4]
%           format: [gx, gy, gx, b]
%
% Optional input:
% ---------------
%    3. mask (boolean; [x, y, x]), providing a mask limits the
%       calculation to a user-defined region-of-interest.
%       default: mask = full FOV
%
%    4 . constraints (boolean; [1, 3] as in [c1, c2, c3]), imposes
%       user-defined constraint to the weighted linear leasts squares
%       estimation of the diffusion kurtosis tensor.
%       Following constraints are available:
%           c1: Dapp > 0
%           c2: Kapp > 0
%           c3: Kapp < 3/(b*Dapp)
%       default: [0 1 0]
%     5. maxbval (scalar; default = 2.5ms/um^2), puts an upper bound on the b-values being
%     used in the analysis.
%
% Copyright (c) 2017 New York University and University of Antwerp
%
% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this file,
% You can obtain one at http://mozilla.org/MPL/2.0/
%
% This code is distributed  WITHOUT ANY WARRANTY; without even the
% implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
%
% For more details, contact: Jelle.Veraart@nyumc.org


%% Set Tolarance Levels
minParam = 1e-8;   % Smallest acceptable diffusion and kurtosis value. Values lower than this are considered violations

%% limit DKI fit to b=3000
bval = grad(:, 4);
order = floor(log(abs(max(bval)+1))./log(10));
if order >= 2
    grad(:, 4) = grad(:, 4)/1000;
    bval = grad(:, 4);
end

if ~exist('maxbval','var') || isempty(maxbval)
    maxbval = 2.5;
end
list = bval<=maxbval;
dwi = dwi(:,:,:,list);
grad = grad(list, :);

%% parameter checks
dwi = double(dwi);
dwi(dwi<=0)=eps;
[x, y, z, ndwis] = size(dwi);
if ~exist('grad','var') || size(grad,1) ~= ndwis || size(grad,2) ~= 4
    error('');
end
grad = double(grad);
grad(:,1:3) = bsxfun(@rdivide,grad(:,1:3),sqrt(sum(grad(:,1:3).^2,2))); grad(isnan(grad)) = 0;
bval = grad(:, 4);
largestBval = max(bval);
imgDirs = length(find(bval == largestBval));
if ~exist('mask','var') || isempty(mask)
    mask = true(x, y, z);
end

if ~exist('outliers', 'var') || isempty(outliers)
    outliers = false(size(dwi));
else
    outliers = outliers(:,:,:,list);
end

dwi = vectorize(dwi, mask);
outliers = vectorize(outliers, mask);

if exist('constraints', 'var') && ~isempty(constraints) && numel(constraints)==3
else
    constraints = [0 1 0];
end
constraints = constraints > 0;
%% tensor fit
[D_ind, D_cnt] = createTensorOrder(2);
[W_ind, W_cnt] = createTensorOrder(4);

bS = ones(ndwis, 1);
bD = D_cnt(ones(ndwis, 1), :).*grad(:,D_ind(:, 1)).*grad(:,D_ind(:, 2));
bW = W_cnt(ones(ndwis, 1), :).*grad(:,W_ind(:, 1)).*grad(:,W_ind(:, 2)).*grad(:,W_ind(:, 3)).*grad(:,W_ind(:, 4));

b = [bS, -bval(:, ones(1, 6)).*bD, (bval(:, ones(1, 15)).^2/6).*bW];


% unconstrained LLS fit
dt = b\log(dwi);
w = exp(b*dt);

nvoxels = size(dwi,2);

% WLLS fit initialized with LLS
if any(constraints)
    dir = [0.382517725304416 -0.748614094922528 0.541532202838631;-0.266039846728327 0.963894740823927 0.0113898448076587;-0.128563443377023 0.800867622029815 0.584878186472493;0.691696803043553 0.485345502199397 0.534785261721136;0.776929615593511 -0.627201085171846 0.0547646891069225;-0.314229418625565 0.891550800503996 0.326185595314880;-0.984699447847175 0.0338717154803320 0.170937720529697;0.729869942283584 0.134539815263771 0.670215566411097;0.0491118066650937 0.613801560175467 0.787931262974286;0.615167937666214 0.786762996419759 0.0507187926916626;-0.504930428375015 -0.548805916531712 0.666226184175323;0.514775318788445 0.353967263592948 0.780841563616317;-0.306616550550256 0.577152309970495 0.756889359169743;-0.644455563348338 0.445243323148325 0.621639292565402;0.888177219438464 0.244852048242751 0.388829913126405;-0.115867623474531 0.331617270421714 0.936271691224516;0.312724982544119 -0.262437525100548 0.912868901163732;-0.348318356641730 -0.328727572647744 0.877845376707953;0.622993255900061 -0.170127400464004 0.763502502100944;-0.870285082134136 -0.0832402149084147 0.485463636575162;0.879693901263504 -0.0847887289384472 0.467920411528283;0.375735817168569 0.624963320743740 0.684283160264539;-0.763508679267313 0.569075961898599 0.305298290648126;0.895786299773340 -0.371201461149296 0.244492086536589;0.431182280410191 0.0594580709470589 0.900303603713504;-0.927083085686508 -0.288337655567580 0.239537781186549;0.208899044398678 0.833216349905585 0.511968459477078;-0.671275756453876 -0.252498824452251 0.696873878436771;-0.385511621254227 -0.908766073079027 0.159765497834991;-0.501120479467597 0.703268192077924 0.504273849281930;-0.578440272143465 0.801933906922628 0.149361509400528;0.986601726072896 -0.0507533113495985 0.155052041254001;0.0472262384668294 -0.790665651327184 0.610424041311968;0.957038035873056 0.279601625450131 0.0768188058868917;-0.497573767044291 -0.0342706449545790 0.866744408256408;0.537095370960702 0.746985750118871 0.391842891490881;0.174500355902118 -0.559258086805823 0.810419655568845;-0.0648836431571087 -0.997212186937296 0.0368506048036694;-0.200896533381969 0.00230971954655800 0.979609742739793;-0.436037609875685 0.290696319170598 0.851684714430502;0.332217034685261 0.924381756972555 0.187483890618005;0.115538097684954 0.0265470728743124 0.992948236770250;-0.167448247267712 -0.594347070791611 0.786582890691377;-0.931940478288593 0.352679013976080 0.0842879471104161;0.749660835628331 -0.375215305423717 0.545180801295148;-0.112213298457421 -0.929475988744578 0.351400856567817;-0.596160909541517 -0.730179079768923 0.333812344592648;0.211077351410955 0.350067854669890 0.912632921194583;-0.325168748302559 -0.780267672863407 0.534273004943793;-0.717210613875971 0.128994202815781 0.684813427864535;-0.0218381924490005 -0.303713916706869 0.952512965869302;0.213275433291729 -0.924500457406975 0.315931153589701;-0.810453788321924 -0.574858547954973 0.112704511168551;0.665549405791414 -0.637998127347686 0.387301404530814;0.489520321770316 -0.495410872500818 0.717591751612200;0.514060443295042 -0.837385561080287 0.185815184346054;-0.757892441488769 -0.466692556842526 0.455847676885577;0.00471100435105065 0.958734616992657 0.284263505603424;0.800137357904460 0.555340864988139 0.226664360144898;-0.872328992553570 0.265326196661285 0.410663046932313;];
    ndir = size(dir, 1);
    C = [];
    if constraints(1)>0
        C = [C; [zeros(ndir, 1), D_cnt(ones(ndir, 1), :).*dir(:,D_ind(:, 1)).*dir(:,D_ind(:, 2)), zeros(ndir, 15)]];
    end
    if constraints(2)>0
        C = [C; [zeros(ndir, 7), W_cnt(ones(ndir, 1), :).*dir(:,W_ind(:, 1)).*dir(:,W_ind(:, 2)).*dir(:,W_ind(:, 3)).*dir(:,W_ind(:, 4))]];
    end
    if constraints(3)>0
        C = [C; [zeros(ndir, 1), 3/max(bval)*D_cnt(ones(ndir, 1), :).*dir(:,D_ind(:, 1)).*dir(:,D_ind(:, 2)), -W_cnt(ones(ndir, 1), :).*dir(:,W_ind(:, 1)).*dir(:,W_ind(:, 2)).*dir(:,W_ind(:, 3)).*dir(:,W_ind(:, 4))]];
    end
    d = zeros([1, size(C, 1)]);
    options = optimset('Display', 'off', 'Algorithm', 'interior-point', 'MaxIter', 22000, 'TolCon', 1e-12, 'TolFun', 1e-12, 'TolX', 1e-12, 'MaxFunEvals', 220000);
    output = struct();
    parfor i = 1:nvoxels
        try
            in_ = outliers(:, i) == 0;
            wi = w(:,i); Wi = diag(wi(in_));
            [dt(:, i),~,~,~,output,~] = lsqlin(Wi*b(in_, :),Wi*log(dwi(in_,i)),-C, d, [],[],[],[],[],options);
        catch
            dt(:, i) = 0;
        end
    end
else
    parfor i = 1:nvoxels
        in_ = outliers(:, i) == 0;
        b_ = b(in_, :);
        if isempty(b_) || cond(b(in_, :))>1e15
            dt(:, i) = NaN
        else
            wi = w(:,i); Wi = diag(wi(in_));
            logdwii = log(dwi(in_,i));
            dt(:,i) = (Wi*b_)\(Wi*logdwii);
        end
    end
end

b0 = exp(dt(1,:));
dt = dt(2:22, :);
D_apprSq = 1./(sum(dt([1 4 6],:),1)/3).^2;
dt(7:21,:) = dt(7:21,:) .* D_apprSq(ones(15,1),:);
b0 = vectorize(b0, mask);


%% Compute Violations
% Find unconstrained diffusion tensor
parfor i = 1:nvoxels
    in_ = outliers(:, i) == 0;
    b_ = b(in_, :);
    if isempty(b_) || cond(b(in_, :))>1e15
        dtV(:, i) = NaN
    else
        wi = w(:,i); Wi = diag(wi(in_));
        logdwii = log(dwi(in_,i));
        dtV(:,i) = (Wi*b_)\(Wi*logdwii);
    end
end
dtV = dtV(2:22, :);
D_apprSq = 1./(sum(dtV([1 4 6],:),1)/3).^2;
dtV(7:21,:) = dtV(7:21,:) .* D_apprSq(ones(15,1),:);
[akc, adc] = AKC(dtV, grad(:,1:3));
adc = adc(find(bval == largestBval),:);
akc = akc(find(bval == largestBval),:);

%   Check and count direction violations in AKC
%   Iterates along all voxels and count the total number of violations
%   occuring per voxel. Every constraint violation is a unique violation so
%   total violations per voxel is sum of direction violations in C1, C2 and
%   C3.

sumViol = zeros(1,nvoxels);
for i = 1:nvoxels
    
    % For constraint 1
    viol.Dmin = find(adc(:,i) <= minParam);
    
    % For constraint 2
    viol.Kmin = find(akc(:,i) <= minParam);
    
    % For constraint 3
    viol.DKrs = find(akc(:,i) >= (3 / largestBval * adc(:,i)));
    
    if constraints(1) == 1 & constraints(2) == 0 & constraints(3) == 0
        % [1 0 0]
        sumViol(i) = numel(viol.Dmin);
        
    elseif constraints(1) == 0 & constraints(2) == 1 & constraints(3) == 0
        % [0 1 0]
        sumViol(i) = numel(viol.Kmin);
        
    elseif constraints(1) == 0 & constraints(2) == 0 & constraints(3) == 1
        % [0 0 1]
        sumViol(i) = numel(viol.DKrs);
        
    elseif constraints(1) == 1 & constraints(2) == 1 & constraints(3) == 0
        % [1 1 0]
        sumViol(i) = numel(unique(cat(1,viol.Dmin,viol.Kmin)));
        
    elseif constraints(1) == 1 & constraints(2) == 0 & constraints(3) == 1
        % [1 0 1]
        sumViol(i) = numel(unique(cat(1,viol.Dmin,viol.DKrs)));
        
    elseif constraints(1) == 0 & constraints(2) == 1 & constraints(3) == 1
        % [0 1 1]
        sumViol(i) = numel(unique(cat(1,viol.Kmin,viol.DKrs)));
        
    elseif constraints(1) == 1 & constraints(2) == 1 & constraints(3) == 1
        % [1 1 1]
        sumViol(i) = numel(unique(cat(1,viol.Dmin,viol.Kmin,viol.DKrs)));
    end
end

% A legal violation is one where there are more than 50% directional
% violations and at least 15 directional violations. We first check for
% proportions of violation where any voxels that has over 50% violations is
% marked for replacement. Then we check for at voxels with less than 15
% good directions, where the voxel meeting this criteria is marked for
% replacement.

parfor i = 1:length(sumViol)
    Proportional(i) = sumViol(i) / imgDirs;
    Directional(i) = imgDirs - sumViol(i);
end

violMask.Proportional = Proportional;
violMask.Directional = Directional;


% Reshape violation logical vector into a logical mask. Locations where a
% voxel = 1 is where a violation occured.

violMask.Proportional = vectorize(violMask.Proportional, mask);
violMask.Directional = vectorize(violMask.Directional, mask);
violMask.Proportional(isnan(violMask.Proportional)) = 0;
violMask.Directional(isnan(violMask.Directional)) = imgDirs;
% disp(sprintf('...found %d total constraint violations',nnz(violMask)));
dt = vectorize(dt, mask);
end

function [akc, adc] = AKC(dt, dir)

[W_ind, W_cnt] = createTensorOrder(4);

adc = ADC(dt(1:6, :), dir);
md = sum(dt([1 4 6],:),1)/3;

ndir  = size(dir, 1);
T =  W_cnt(ones(ndir, 1), :).*dir(:,W_ind(:, 1)).*dir(:,W_ind(:, 2)).*dir(:,W_ind(:, 3)).*dir(:,W_ind(:, 4));

akc =  T*dt(7:21, :);
akc = (akc .* repmat(md.^2, [size(adc, 1), 1]))./(adc.^2);
end

function [adc] = ADC(dt, dir)
[D_ind, D_cnt] = createTensorOrder(2);
ndir  = size(dir, 1);
T =  D_cnt(ones(ndir, 1), :).*dir(:,D_ind(:, 1)).*dir(:,D_ind(:, 2));
adc = T * dt;
end

function [X, cnt] = createTensorOrder(order)
X = nchoosek(kron([1, 2, 3], ones(1, order)), order);
X = unique(X, 'rows');
for i = 1:size(X, 1)
    cnt(i) = factorial(order) / factorial(nnz(X(i, :) ==1))/ factorial(nnz(X(i, :) ==2))/ factorial(nnz(X(i, :) ==3));
end

end

function [s, mask] = vectorize(S, mask)
if nargin == 1
    mask = ~isnan(S(:,:,:,1));
end
if ismatrix(S)
    n = size(S, 1);
    [x, y, z] = size(mask);
    s = NaN([x, y, z, n], 'like', S);
    for i = 1:n
        tmp = NaN(x, y, z, 'like', S);
        tmp(mask(:)) = S(i, :);
        s(:,:,:,i) = tmp;
    end
else
    for i = 1:size(S, 4)
        Si = S(:,:,:,i);
        s(i, :) = Si(mask(:));
    end
end
end