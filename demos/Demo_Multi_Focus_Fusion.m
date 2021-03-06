% Multi-focus Image Fusion Demo script.

% This script demonstrates LoBCoD for Multi-Focus image fusion.
% The script loads the following variables:
%  
% (1) Foreground_inFocus, Background_inFocus
%            - Target images to fuse.
% (2) D_init - The initial dictionary used to represent the edge-components.
% (3) Gx, Gy - The gradient matrices used for gradient calculation in
%              the horizontal and vertical directions.
% (4) G      - The gradient matrix "G = eye + mu*(Gx'*Gx+Gy'*Gy)".
% 
clear;

% Load necessary dependencies
addpath('functions')
addpath mexfiles;
addpath image_helpers;
addpath('vlfeat/toolbox');
addpath('utilities');
addpath(genpath('spams-matlab'));
vl_setup();

% This mat file contains Background_inFocus, Foreground_inFocus, D_init
% G, Gx, Gy and z_bird_rgb variables
load('datasets/Multi_Focus_example/Multi_Focus_param.mat');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%START%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%    MODIFY THIS PART IF YOU WANT TO CHANGE THE INPUT IMAGE!    %%%%%%

% Background_inFocus = imread('datasets/Multi_Focus_example/background_inFocus_sheep.jpg');
% Foreground_inFocus = imread('datasets/Multi_Focus_example/foreground_inFocus_sheep.jpg');
% z_sheep_rgb = imread('datasets/Multi_Focus_example/sheep.jpeg');

% This size is calculated by the image size 226x300, 
% pad it with one zero each side => (226+2)x(300+2)
% reshape it to a vector of size 228 * 302 = 68,856
n = 68856; 
D = sparse(1:n,1:n,ones(1,n),n,n);
E = sparse(2:n,1:n-1,-1*ones(1,n-1),n,n);
Gx = D+E';
Gy = E+D;
mu = 5;
G = speye(n) + mu*(Gx'*Gx+Gy'*Gy);

Background_inFocus = imread('datasets/Multi_Focus_example/background_inFocus_sheep.jpg');
Foreground_inFocus = imread('datasets/Multi_Focus_example/foreground_inFocus_sheep.jpg');
ground_truth = imread('datasets/Multi_Focus_example/sheep.jpeg');

% Transform blurred colored images to the Lab color space
Background_inFocus_lab = rgb2lab(Background_inFocus);
Foreground_inFocus_lab = rgb2lab(Foreground_inFocus);
% ground_truth = rgb2lab(z_bird_rgb);
I_original = rgb2lab(ground_truth);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%END%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

lambda = 1;
n =  sqrt(size(D_init,1));
m = size(D_init,2);
MAXITER_pursuit = 250;

I = cell(1,2);
sz = cell(1,2);

% Run the algorithm on the L channels
I{1} = Background_inFocus_lab(:,:,1);
I{2} = Foreground_inFocus_lab(:,:,1);
I_original = double(I_original(:,:,1));

sz{1} = size(I{1});
sz{2} = size(I{2});
sz_vec = sz{1}(1)*sz{1}(2);
N=length(I);
patches = myim2col_set_nonoverlap(I{1}, n);

% Initialize variables
MAXITER = 2;
Xb = cell(1,N);
X_resb = cell(1,N);
X_res_e = cell(1,N);
alpha =  cell(1,N);
Xe = cell(1,N);

params = [];
params.lambda = lambda;
params.MAXITER = MAXITER_pursuit;
params.D = D_init;
params.Train_on = false(1);

% Update the dictionary matrix via LoBCoD
for k=1:N
    Xe{k} = zeros(size(I{k}));
end
% Alternate between minimizing w.r.t. the base component Yb and
% the feature map Zi
for outerIter = 1 : MAXITER
    for i=1:N
        X_resb{i} = I{i}-Xe{i};
        X_resb{i} = padarray(X_resb{i},[1 1],'symmetric','both');
        % lsqminnorm: Minimum-norm solution of least-square system
        % returns a vector X that minimizes norm(A*X - B)
        Xb{i} = reshape(lsqminnorm(G,X_resb{i}(:)),(sz{i}(1)+2),(sz{i}(2)+2));
        Xb{i} = real(Xb{i}(1:sz{1}(1),1:sz{1}(2)));
        X_res_e{i} = I{i}-Xb{i};
  
    end

    params.Ytrain = X_res_e;
    % alpha: the output sparse needles. 
    [Xe,objective,avgpsnr,sparsity,totTime,alpha,~] = LoBCoD(params);
    D_opt = D_init;

end

fprintf('Finish updating the dictionary!\n');
%% Fusion

[feature_maps,~] = create_feature_maps(alpha,n,m,sz{1},D_opt);

fused_feature_maps = cell(1);
fused_feature_maps{1} = cell(size(feature_maps{1}));

% Build an activity map A
A = cell(1,N);
A{1} = abs(feature_maps{1}{1});
A{2} = abs(feature_maps{2}{1});
for j=2:m
   A{1} = A{1}+abs(feature_maps{1}{j});
   A{2} = A{2}+abs(feature_maps{2}{j});
end

fprintf('Finish building the activity map!\n');

% Convolve A with a uniform kernel k
k = (1/14)*ones(14,14);
A{1} = rconv2(A{1},k);
A{2} = rconv2(A{2},k);

fprintf('Finish convolving A with a uniform kernel k!\n');

% Reconstruct the all-in-focus components by assembling the most prominent
% regions based on their values in the corresponding activity maps
for j=1:m
    fused_feature_maps{1}{j} = (A{1}>=A{2}).*feature_maps{1}{j}+(A{1}<A{2}).*feature_maps{2}{j};
end

% the fusion result is obtained by gathering its components:
% Yf = Yb + sum(1~m)di*Zi
[alpha_fused,I_rec] = extract_feature_maps(fused_feature_maps,n,m,sz{1},D_opt);
Clean_xe = cell(1,length(patches));
for j=1:n^2 
   Clean_xe{j}= D_opt*alpha_fused{1}{j};
end
       
fused_image_e = mycol2im_set_nonoverlap(Clean_xe,sz{1}, n);
% Compute the base component of the fused image Yf
fused_image_b = (A{1}>=A{2}).*Xb{1}+(A{1}<A{2}).*Xb{2};
ours_lab = Foreground_inFocus_lab;
ours_lab(:,:,1)= fused_image_e+fused_image_b;
ours_lab(:,:,2) = (A{1}>=A{2}).*double(Background_inFocus_lab(:,:,2))+(A{1}<A{2}).*double(Foreground_inFocus_lab(:,:,2));
ours_lab(:,:,3) = (A{1}>=A{2}).*double(Background_inFocus_lab(:,:,3))+(A{1}<A{2}).*double(Foreground_inFocus_lab(:,:,3));
fprintf('Finish fusing the two images!\n');

% PSNR calculation, ignoring boundaries
PSNR = 20*log10((255*sqrt(numel(I{1}(8:sz{1}-8,8:sz{1}-8))) / norm(reshape(fused_image_e(8:sz{1}-8,8:sz{1}-8)+fused_image_b(8:sz{1}-8,8:sz{1}-8) - I_original(8:sz{1}-8,8:sz{1}-8),1,[]))));
fprintf('PSNR: %.3f\n',PSNR);

figure; 
subplot(2,2,1); imagesc(Background_inFocus); title('Background in-focus'); axis off
subplot(2,2,2); imagesc(Foreground_inFocus); title('Foreground in-focus'); axis off
subplot(2,2,3); imagesc(ground_truth); title('Ground truth'); axis off
subplot(2,2,4); imagesc((lab2rgb(ours_lab))); title(['Our result PSNR: ',num2str(PSNR,4),'dB']); axis off
