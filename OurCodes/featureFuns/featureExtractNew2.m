function result = featureExtractNew2(varargin)
% result = featureExtractNew1(image,spinfor,flow, LEND)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ��ȡ���򼶵�������Ϣ��������ڹ����ֵ䣩
% image ͼ��
% spinfor ��߶ȷָ���Ϣ
% 
% result.D0  objIndex��Ϊ��ʱ�������ֵ�D0 sampleNum*FeaDims
% D0.P D0.N
% result.selfFea
% result.multiContextFea
% result.ORLabels
%
% V1��2016.08.23 16:33PM
% V2: 2016.10.09 19:29PM
% ����ORLabelѡ��ȷ����ѵ��������object/border�ֱ���Ϊ����������
%
% V3��2016.10.12 8:38AM
% ���챳���ֵ������Ԫ�أ�����������һ��
%
% V4�� 2016.10.24 9:12AM
% ��context����ת��Ϊȫ������
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
image   = varargin{1};% height*width*3
spinfor = varargin{2};% ��߶ȷָ���Ϣ
flow    = varargin{3};% ������ height*width*2
LCEND   = varargin{4};% [x1,y1,x2,y2]
param   = varargin{5};% ����������ȷ��ORlabel

if nargin==6
    objIndex = varargin{6};% GT��ǩ���
else
    objIndex = [];
end

image = double(image);
[height,width,dims] = size(image);
ScaleNums = length(spinfor);
NUM_COLORS = 48;
numOfBins = NUM_COLORS/3;
range_rgb = [0,255;0,255;0,255];
range_lab = [0,100;-127,128;-127,128]; 
range_hsv = [0,360;0,1;0,1];

%% OR�����ǩ %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% <L 0; >=H 1; L~H 50
% ��ʱ��LCENDӦ��Ϊԭͼ��ߴ��С
% LCEND = [1,1,width,height];
ORLabels = computeORLabel(LCEND, objIndex, spinfor, param);

%% preparation work %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% color transform ------------------
im_R = image(:,:,1);
im_G = image(:,:,2);
im_B = image(:,:,3);

[im_L, im_A, im_B1] = ...
    rgb2lab_dong(double(im_R(:)),double(im_G(:)),double(im_B(:)));
im_L=reshape(im_L,size(im_R));
im_A=reshape(im_A,size(im_R));
im_B1=reshape(im_B1,size(im_R));
        
imgHSV=colorspace('HSV<-',uint8(image));      
im_H=imgHSV(:,:,1);
im_S=imgHSV(:,:,2);
im_V=imgHSV(:,:,3);

% texture computation --------------
% 1 LBP
grayim = rgb2gray( uint8(image) );
[imlbp,~] = LBP_uniform(double(grayim));
im_LBP = double( imlbp );
clear imlbp grayim

% 2 covariance
I = (im_R+im_G+im_B)/3;
CovDists = [-1 0 1];
Iy = imfilter(I,CovDists,'symmetric','same','conv');
Ix = imfilter(I,CovDists','symmetric','same','conv');
Ixx = imfilter(Ix,CovDists','symmetric','same','conv');
Iyy = imfilter(Iy,CovDists,'symmetric','same','conv');
[s2, s1] = meshgrid(1:width,1:height);
F = zeros(height,width,1);
F(:,:,1) = im_L;F(:,:,2) = im_A;F(:,:,3) = im_B1;
F(:,:,4) = abs(Ix);F(:,:,5) = abs(Iy);
F(:,:,6) = s1;F(:,:,7) = s2;
F(:,:,8) = abs(Ixx);F(:,:,9) = abs(Iyy);
for i=1:size(F,3)
    F(:,:,i) = F(:,:,i)/max(max(F(:,:,i)));
end
im_COV = reshape(F,[size(F,1)*size(F,2), size(F,3)]);
clear F I Iy Ix Ixx Iyy  

% % motion --------------------------
% Magn=sqrt(flow(:,:,1).^2+flow(:,:,2).^2);    
% Ori=atan2(-flow(:,:,1),flow(:,:,2));


%% compute features of sp %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
selfFea = cell(ScaleNums,1);
multiContextFea = cell(ScaleNums,1);
for ss=1:ScaleNums
    tmpSP = spinfor{ss,1};
    
    % color
    colorHist_rgb = zeros(tmpSP.spNum,3*numOfBins);
    colorHist_lab = zeros(tmpSP.spNum,3*numOfBins);
    colorHist_hsv = zeros(tmpSP.spNum,3*numOfBins);
    
    % texture
    lbpHist = zeros(tmpSP.spNum,59);
    hogHist = zeros(tmpSP.spNum,4*36);
    
    regionCov = COVSIGMA(im_COV,tmpSP.idxcurrImage,tmpSP.spNum);
    
    rect_width = round(sqrt(height*width/tmpSP.spNum)*2/3);% HOG���������С
    
    % motion
    [flowHist, ~] = computeMotionHist(flow,tmpSP.spNum,tmpSP.pixelList,8);% spNum*16
    
    for sp=1:tmpSP.spNum
     pixelList = tmpSP.pixelList{sp,1};
    %% color --------------------- 
    colorHist_rgb(sp,:) = computeColorHist(im_R,im_G,im_B,pixelList,numOfBins,range_rgb);     
    colorHist_lab(sp,:) = computeColorHist(im_L,im_A,im_B1,pixelList,numOfBins,range_lab);   
    colorHist_hsv(sp,:) = computeColorHist(im_H,im_S,im_V,pixelList,numOfBins,range_hsv);   
     
    %% texture ------------------
    % LBP
    lbpHist(sp,:) = hist_dong(im_LBP(pixelList),59,[0,58],0);% hist( imlbp(pixels), 0:255 )'
    lbpHist(sp,:) = lbpHist(sp,:) / max( sum(lbpHist(sp,:)), eps );

    % HOG
    [ys,xs] = ind2sub([height,width],pixelList);
    miny=min(ys);maxy=max(ys);
    minx=min(xs);maxx=max(xs);
    hh = maxy-miny+1;ww=maxx-minx+1;
    yc = miny + round(hh/2);
    xc = minx + round(ww/2);
    rect_width = min(hh,ww);
    hh1 = (yc-round(rect_width/2)):(yc+round(rect_width/2)-1);
    ww1 = (xc-round(rect_width/2)):(xc+round(rect_width/2)-1);
    if (yc-round(rect_width/2))<1
        hh1=1:(yc+round(rect_width/2));
    end
    if (yc+round(rect_width/2))>height
        hh1 = (yc-round(rect_width/2)):height;
    end    
    if (xc-round(rect_width/2))<1
        ww1=1:(xc+round(rect_width/2));
    end
    if (xc+round(rect_width/2))>width
        ww1 = (xc-round(rect_width/2)):width;
    end   
    subimg = image(hh1,ww1,:);
    
    if rect_width<6 % ȷ����С��cell�ĳߴ�Ϊ 3*3 2016.09.01 18:55PM
        rect_width = 6;
    end
    subimg = imresize(subimg,[rect_width,rect_width]);
    % ȷ��2*2�Ĺ��� revised in 2016.08.30 20:45PM
    cellsize_hog = round(rect_width/2);
    tmphog = vl_hog(single(subimg), cellsize_hog, 'Variant', 'DalalTriggs', 'NumOrientations', 9);
    hogHist(sp,:) = tmphog(:); % 1*(2*2*36)
%     disp([ss,sp])
    clear x y hh ww subimg tmphog
    
    end
    %% GD (ȫ�ַ�Χ�ڣ�����OR)
     adjcMatrix = tmpSP.adjcMatrix;
     bdIds = tmpSP.bdIds;
     colDistM = tmpSP.colDistM;
     posDistM = tmpSP.posDistM;     
     [clipVal, ~, ~] = EstimateDynamicParas(adjcMatrix, colDistM);
     geoDist = GeodesicSaliency(adjcMatrix, bdIds, colDistM, posDistM, clipVal);% length(index01)*1
     geoDist = normalizeSal(geoDist);
     clear  adjcMatrix colDistM posDistM clipVal
     
     %% ���� MultiContrast ����(ȫ���µĶ�-context��Ϣ)
     tmpORlabel = ORLabels{ss,1};% spNum*3
     colorHist_rgb_contrast = computeMultiContrast(colorHist_rgb,tmpSP,tmpORlabel);
     colorHist_rgb_contrast(isnan(colorHist_rgb_contrast)) = 0;
     multiContextFea{ss,1}.colorHist_rgb = colorHist_rgb_contrast;
     
     colorHist_lab_contrast = computeMultiContrast(colorHist_lab,tmpSP,tmpORlabel);
     colorHist_lab_contrast(isnan(colorHist_lab_contrast)) = 0;
     multiContextFea{ss,1}.colorHist_lab = colorHist_lab_contrast;
     
     colorHist_hsv_contrast = computeMultiContrast(colorHist_hsv,tmpSP,tmpORlabel);
     colorHist_hsv_contrast(isnan(colorHist_hsv_contrast)) = 0;
     multiContextFea{ss,1}.colorHist_hsv = colorHist_hsv_contrast;
     
     lbpHist_contrast = computeMultiContrast(lbpHist,tmpSP,tmpORlabel);
     lbpHist_contrast(isnan(lbpHist_contrast)) = 0;
     multiContextFea{ss,1}.lbpHist       = lbpHist_contrast;
     
     hogHist_contrast = computeMultiContrast(hogHist,tmpSP,tmpORlabel);
     hogHist_contrast(isnan(hogHist_contrast)) = 0;
     multiContextFea{ss,1}.hogHist       = hogHist_contrast;
     
     regionCov_contrast = computeMultiContrast(regionCov,tmpSP,tmpORlabel);
     regionCov_contrast(isnan(regionCov_contrast)) = 0;
     multiContextFea{ss,1}.regionCov     = regionCov_contrast;
     
     geoDist_contrast = computeMultiContrast(geoDist',tmpSP,tmpORlabel);
     geoDist_contrast(isnan(geoDist_contrast))  = 0;
     multiContextFea{ss,1}.geoDist = geoDist_contrast;
     
     flowHist_contrast = computeMultiContrast(flowHist,tmpSP,tmpORlabel);
     flowHist_contrast(isnan(flowHist_contrast)) = 0;
     multiContextFea{ss,1}.flowHist      = flowHist_contrast;
     
     clear colorHist_rgb_contrast colorHist_lab_contrast colorHist_hsv_contrast 
     clear hogHist_contrast lbpHist_contrast regionCov_contrast geoDist_contrast flowHist_contrast
     
     %% ���� selfFea ����: sampleNum*FeaDims (ȫ���µ�������Ϣ)
     colorHist_rgb(isnan(colorHist_rgb)) = 0;
     colorHist_lab(isnan(colorHist_lab)) = 0;
     colorHist_hsv(isnan(colorHist_hsv)) = 0;
     lbpHist(isnan(lbpHist))             = 0;
     hogHist(isnan(hogHist))             = 0;
     regionCov(isnan(regionCov))         = 0;
     geoDist(isnan(geoDist))             = 0;
     flowHist(isnan(flowHist))           = 0;
     selfFea{ss,1}.colorHist_rgb = colorHist_rgb;
     selfFea{ss,1}.colorHist_lab = colorHist_lab;
     selfFea{ss,1}.colorHist_hsv = colorHist_hsv;  
     selfFea{ss,1}.lbpHist       = lbpHist;
     selfFea{ss,1}.hogHist       = hogHist;
     selfFea{ss,1}.regionCov     = regionCov;   
     selfFea{ss,1}.geoDist       = geoDist';
     selfFea{ss,1}.flowHist      = flowHist;
     
end
clear colorHist_rgb colorHist_lab colorHist_hsv lbpHist hogHist regionCov geoDist flowHist
clear im_R im_G im_B im_L im_A im_B1 im_H im_S im_V

%% ������ʼ�ֵ䣨��߶����������У� ǰ���ֵ䡢 �����ֵ䣩D0
% �����ֵ�ʱ��������OR���Χ 2016.10.24 9:22AM
if 1
if nargin==6
    D0.P = struct;D0.N = struct;% sampleNum*feaDim
    DP_colorHist_rgb = []; DN_colorHist_rgb = [];
    DP_colorHist_lab = []; DN_colorHist_lab = [];
    DP_colorHist_hsv = []; DN_colorHist_hsv = [];
    DP_lbpHist       = []; DN_lbpHist       = [];
    DP_hogHist       = []; DN_hogHist       = [];
    DP_regionCov     = []; DN_regionCov     = [];
    DP_geoDist       = []; DN_geoDist       = [];
    DP_flowHist      = []; DN_flowHist      = [];
    
    for ss=1:ScaleNums
        tmpSP = spinfor{ss,1};
        tmpORlabel = ORLabels{ss,1};% spNum*3
        ISORlabel = tmpORlabel(:,1);
        index_out_OR = find(ISORlabel~=1);
        ISOBJlabel = tmpORlabel(:,3);
        Plabel = ISORlabel.*ISOBJlabel;% (1,1) P % ��ʱORlabelȫΪ1����Ϊ��ԭͼ��ߴ��н��еĲ���
        Plabel(index_out_OR,:) = [];% ȥ��OR�ⲿ����
        indexP = find(Plabel==1);% ȷ��OR��������Щ�� object 

%         if 0
%         % revised in 2016.10.09  19:29PM
%         % ѡ��ȷ���Ե�ѵ������������������border��
%         ISBORDERlabel = tmpORlabel(:,2);
%         ISOBJlabel(ISOBJlabel==1) = 6;% �÷�ISOBJlabel������ȷ��indexN
%         ISOBJlabel(ISOBJlabel==0) = 1;
%         ISOBJlabel(ISOBJlabel==6) = 0;  
%         Nlabel = ISORlabel .* ISOBJlabel .* ISBORDERlabel; % 1 1 1 ---> border �� OR=1�� OBJ=0�� BORDER=1
%         Nlabel(index_out_OR,:) = [];
%         indexN = find(Nlabel==1);
%         end
        
        % revised in 2016.10.12 9:46AM ���������ֵ�Ԫ�� OR=1 OBJECT=0
        % ��ʱORlabelȫΪ1����Ϊ��ԭͼ��ߴ��н��еĲ���
        if 1 % ��OR����OBJ=0��Ϊȷ���Ա���
        [index_in_OR,~] = find(ISORlabel==1);% OR������
        indexN = [];% OR�б��������ţ�1,0��
        for dd=1:length(index_in_OR)
            tmpID = index_in_OR(dd);
            if ISOBJlabel(tmpID)==0
               indexN = [indexN;dd];
            end
        end
        
        end
        
        % ��OR��ȡ��������
        DP_colorHist_rgb = [DP_colorHist_rgb;selfFea{ss,1}.colorHist_rgb(indexP,:),multiContextFea{ss,1}.colorHist_rgb(indexP,:)];
        DP_colorHist_lab = [DP_colorHist_lab;selfFea{ss,1}.colorHist_lab(indexP,:),multiContextFea{ss,1}.colorHist_lab(indexP,:)];
        DP_colorHist_hsv = [DP_colorHist_hsv;selfFea{ss,1}.colorHist_hsv(indexP,:),multiContextFea{ss,1}.colorHist_hsv(indexP,:)];  
        DP_lbpHist       = [DP_lbpHist;      selfFea{ss,1}.lbpHist(indexP,:),      multiContextFea{ss,1}.lbpHist(indexP,:)];
        DP_hogHist       = [DP_hogHist;      selfFea{ss,1}.hogHist(indexP,:),      multiContextFea{ss,1}.hogHist(indexP,:)];
        DP_regionCov     = [DP_regionCov;    selfFea{ss,1}.regionCov(indexP,:),    multiContextFea{ss,1}.regionCov(indexP,:)];
        DP_geoDist       = [DP_geoDist;      selfFea{ss,1}.geoDist(indexP,:),      multiContextFea{ss,1}.geoDist(indexP,:)];
        DP_flowHist      = [DP_flowHist;     selfFea{ss,1}.flowHist(indexP,:),     multiContextFea{ss,1}.flowHist(indexP,:)];
        
        DN_colorHist_rgb = [DN_colorHist_rgb;selfFea{ss,1}.colorHist_rgb(indexN,:),multiContextFea{ss,1}.colorHist_rgb(indexN,:)];
        DN_colorHist_lab = [DN_colorHist_lab;selfFea{ss,1}.colorHist_lab(indexN,:),multiContextFea{ss,1}.colorHist_lab(indexN,:)];
        DN_colorHist_hsv = [DN_colorHist_hsv;selfFea{ss,1}.colorHist_hsv(indexN,:),multiContextFea{ss,1}.colorHist_hsv(indexN,:)];  
        DN_lbpHist       = [DN_lbpHist;      selfFea{ss,1}.lbpHist(indexN,:),      multiContextFea{ss,1}.lbpHist(indexN,:)];
        DN_hogHist       = [DN_hogHist;      selfFea{ss,1}.hogHist(indexN,:),      multiContextFea{ss,1}.hogHist(indexN,:)];
        DN_regionCov     = [DN_regionCov;    selfFea{ss,1}.regionCov(indexN,:),    multiContextFea{ss,1}.regionCov(indexN,:)];
        DN_geoDist       = [DN_geoDist;      selfFea{ss,1}.geoDist(indexN,:),      multiContextFea{ss,1}.geoDist(indexN,:)];
        DN_flowHist      = [DN_flowHist;     selfFea{ss,1}.flowHist(indexN,:),     multiContextFea{ss,1}.flowHist(indexN,:)];     
        
    end
    D0.P.colorHist_rgb = DP_colorHist_rgb; 
    D0.P.colorHist_lab = DP_colorHist_lab; 
    D0.P.colorHist_hsv = DP_colorHist_hsv; 
    D0.P.lbpHist       = DP_lbpHist;
    D0.P.hogHist       = DP_hogHist;
    D0.P.regionCov     = DP_regionCov;
    D0.P.geoDist       = DP_geoDist;
    D0.P.flowHist      = DP_flowHist;
    
    D0.N.colorHist_rgb = DN_colorHist_rgb; 
    D0.N.colorHist_lab = DN_colorHist_lab; 
    D0.N.colorHist_hsv = DN_colorHist_hsv; 
    D0.N.lbpHist       = DN_lbpHist;
    D0.N.hogHist       = DN_hogHist;
    D0.N.regionCov     = DN_regionCov;
    D0.N.geoDist       = DN_geoDist;
    D0.N.flowHist      = DN_flowHist;
    
    % SAVE
    result.D0 = D0;
    
    clear D0
end
end
%% save
result.selfFea         = selfFea;% ȫ�ߴ��������������г߶��µ���������
result.multiContextFea = multiContextFea;
result.ORLabels        = ORLabels;

clear selfFea multiContextFea ORLabels
clear image spinfor flow LCEND param 



end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%2 ���������˶���Ϣ &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
function [flowHistTable_SP, meanMagnOri_SP] = computeMotionHist(flow,numSP,pixelList,numOfBins)
% ���ȡ���λ��������
curFlow=double(flow);
Magn=sqrt(curFlow(:,:,1).^2+curFlow(:,:,2).^2);    
Ori=atan2(-curFlow(:,:,1),curFlow(:,:,2));
    
flowHistTable=zeros(numSP,3*numOfBins);
%the first col for magnitude,the second for orientation,the last probabilty
meanMagnOri=zeros(numSP,2);
for sp=1:numSP
    bin=0;
    curOri=Ori(pixelList{sp,1});
    curMagn=Magn(pixelList{sp,1});
    % the mean magnitude for each superpixels
    meanMagnOri(sp,1)=mean(curMagn);
    meanMagnOri(sp,2)=median(curOri);
        
    for angle=(-pi+2*pi/numOfBins):2*pi/numOfBins:pi
        bin=bin+1;
        index=curOri<=angle;
        if sum(sum(index))==0
           flowHistTable(sp,bin)=angle;
        else
           flowHistTable(sp,bin)=mean(curOri(index));
        end
           flowHistTable(sp,bin+numOfBins)=sum(curMagn(index));
           flowHistTable(sp,bin+2*numOfBins)=sum(sum(index));      
           curOri(index)=Inf;
    end
    
    %normalize
    temp= flowHistTable(sp,numOfBins+1:2*numOfBins);
    temp=temp./flowHistTable(sp,2*numOfBins+1:3*numOfBins);
    isNaN=isnan(temp);
    temp(isNaN)=0;
    flowHistTable(sp,numOfBins+1:2*numOfBins)=temp;
    flowHistTable(sp,2*numOfBins+1:3*numOfBins)=normalizeFeats(flowHistTable(sp,2*numOfBins+1:3*numOfBins));
        
end

%save the data
flowHistTable_SP = flowHistTable(:,numOfBins+1:end);    
meanMagnOri_SP   = meanMagnOri;
clear flow numSP pixelList numOfBins flowHistTable meanMagnOri
end

%3 ������ɫֱ��ͼ��rgb/hsv/lab &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
function colorHist = computeColorHist(imx,imy,imz,pixelList,numOfBins,ranges)
colorHist = zeros(1,numOfBins*3);
     hist_sample=[];
     hist_sample(1,:)=imx(pixelList);
     hist_sample(2,:)=imy(pixelList);
     hist_sample(3,:)=imz(pixelList);
     colorHist(1,1:numOfBins)              =hist_dong(hist_sample(1,:)',numOfBins,ranges(1,:),0);
     colorHist(1,numOfBins+1:2*numOfBins)  =hist_dong(hist_sample(2,:)',numOfBins,ranges(2,:),0);
     colorHist(1,2*numOfBins+1:3*numOfBins)=hist_dong(hist_sample(3,:)',numOfBins,ranges(3,:),0); 
     colorHist(1,:)=colorHist(1,:)/sum(colorHist(1,:));
end

%4 �����Աȶ���Ϣ�� local border global &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
% ĳһ�߶��µĶ�Աȶ�����
% 2016.08.24 15:45PM
% ȫ�������µĶ�context���� 2016.10.24 16:36PM
% 
function multiContextFea = computeMultiContrast(fea,tmpSP,tmpORlabel)
[height,width,dims] = size(tmpSP.idxcurrImage);
multiContextFea = zeros(tmpSP.spNum,3);
DistMat = GetDistanceMatrix(fea);
clear fea

bdIds = tmpSP.bdIds;
area = tmpSP.area; 
adjmat = tmpSP.adjmat;
boundary = zeros(tmpSP.spNum,tmpSP.spNum);
boundary(:,bdIds) = 1;

pixelList = cell(tmpSP.spNum,1);
for pp=1:tmpSP.spNum
     pixelList{pp,1} =  tmpSP.pixelList{pp,1};
end

% ���������ԭ����һ���Ļ����ϻ��ٽ���һ�ι�һ��-----------------------------------------------------------------
% lambda_j 
area = (area)';
area = area/sum(area);

% global context
area_all_weight = repmat(area, [tmpSP.spNum, 1])./repmat(sum(area,2)+eps,[tmpSP.spNum,tmpSP.spNum]);

% local adjcent
area_adj_weight = repmat(area, [tmpSP.spNum, 1]) .* adjmat;
area_adj_weight = area_adj_weight ./ repmat(sum(area_adj_weight, 2) + eps, [1, tmpSP.spNum]);  

% area_boundary_weight = area_all_weight.*boundary;
area_boundary_weight = repmat(area, [tmpSP.spNum, 1]) .* boundary;
area_boundary_weight = area_boundary_weight ./ repmat(sum(area_boundary_weight, 2) + eps, [1, tmpSP.spNum]); 
clear area
%  w_ij (global, local and border)----------------------------------------------------------------------------
meanPos = GetNormedMeanPos(pixelList, height, width);
posDistM = GetDistanceMatrix(meanPos);% ȫ�ֵľ���ռ����
posDistM(posDistM==0) = 1e-10;
[maxDistsGlobal,maxIndexGlobal] = max(posDistM,[],2);
posDistM(posDistM==1e-10) = 0;
posDistMGlobal = posDistM./repmat(maxDistsGlobal,[1,tmpSP.spNum]);

posDistM = GetDistanceMatrix(meanPos);
posDistMLocal = posDistM.*adjmat;
posDistMLocal(posDistMLocal==0)=1e-10;
[maxDistsLocal,maxIndexLocal] = max(posDistMLocal,[],2);
posDistMLocal(posDistMLocal==1e-10) = 0;
posDistMLocal = posDistMLocal./repmat(maxDistsLocal,[1,tmpSP.spNum]);

posDistM = GetDistanceMatrix(meanPos);
posDistMBorder = posDistM.*boundary;
posDistMBorder(posDistMBorder==0)=1e-10;
[maxDistsBorder,maxIndexBorder] = max(posDistMBorder,[],2);
posDistMBorder(posDistMBorder==1e-10) = 0;
posDistMBorder = posDistMBorder./repmat(maxDistsBorder,[1,tmpSP.spNum]);

clear meanPos posDistM

% LAMBDA_J*W_IJ ----------------------------------------------------------------------------------------------
dist_weight_global = area_all_weight.*exp( -posDistMGlobal );% global weight
dist_weight_local = area_adj_weight.*exp( -posDistMLocal);% local weight:���ڽ���Ϊ�㣬����Ϊ��
dist_weight_boundary = area_boundary_weight.*exp(-posDistMBorder);% boundary weight: �߽�λ�ò�Ϊ�㣬�Ǳ߽�λ��Ϊ��

multiContextFea(:,1) = sum(DistMat(:,:) .* dist_weight_global, 2) ./ (sum(dist_weight_global, 2) + eps);
multiContextFea(:,2) = sum(DistMat(:,:) .* dist_weight_local, 2) ./ (sum(dist_weight_local, 2) + eps);
multiContextFea(:,3) = sum(DistMat(:,:) .* dist_weight_boundary, 2) ./ (sum(dist_weight_boundary, 2) + eps);

clear dist_weight_global dist_weight_local dist_weight_boundary
end