function predY = classifyTrajClusts(trainX, trainY, testX, varargin)
%predY = classifyTrajClusts(trainX, trainY, testX, varargin)
% trainX is (nTrials x nTimes x nDims(e.g. units))
% trainY is (nTrials x 1)
% testX is nTest x nTimes x nDims
% varargin is kvp 'method', method_name. See listmodels() for possible
% values of method_name.

params.method = 'lrm';  % see listmodels()
params = varg2params(varargin, params, {'model'});

uqClasses = unique(trainY);
nClasses = length(uqClasses);

%% Describes the input to curve_clust
% Trajs
%       .Y   : observed curve values Y{i} is an ni-by-D matrix holding the observed curve
%               values for the i-th curve.
%       .X   : observation time-points at which Trajs.Y was observed (not
%               needed if all curves have same time-points)
%Trajs.Y = arrayfun(@(x) x.xorth(1:keepDim,:)', seqTrain, 'UniformOutput', false);
% [nTrials, nDims, nTimes] = size(nTraj);
% Trajs.Y = squeeze(mat2cell(permute(nTraj, [3 2 1]), nTimes, nDims, ones(1,nTrials)));


% ModelOptions : options structure used to pass required and/or optional
%                     arguments to specific clustering methods.
%   MODEL_OPTIONS (structure)
%     .method      : (R) select clustering algorithm (see below)
%     .K           : (R) number of clusters
%     .order       : order of model to fit
%     .zero        : see Trajs2Seq()
%     .NumEMStarts : number of EM starts
%     .MsgHnd      : handle to MSGBAR figure (-1 to disable)
%     .MsgPrefix   : string to prepend to MSGBAR call
%
%   METHOD (string)
%     Call this function with the single argument 'methods' to display the
%     current list of acceptable methods. In other words, type 
%     curve_clust('methods') at the matlab prompt.
%% Do curve_clust

ModelOptions.method = params.method; %'lrm' 'gmix' 'srm' ListModels()
ModelOptions.K=nClasses;
ModelOptions.zero='none';  % 'none' 'zero' 'zero_nocut' 'mean' 'norm' 'znorm' 'znorm_nocut'
ModelOptions.order=3;
%ModelOptions.IterLimit=200;
ModelOptions.NumEMStarts=6;
%ModelOptions.ShowGraphics	=0;
model = curve_clust(trainX, ModelOptions);
%showmodel(model,trainX);
% AIC=2*model.K - 2*model.TrainLhood_ppt;

%% Try to determine which cluster belongs to which behaviour class.

%For each true class, find the number of trials in each that 
coincCount = zeros(nClasses);
for tc = 1:nClasses  % true class
    for mc = 1:nClasses  % mapped class
        coincCount(tc, mc) = sum(trainY==uqClasses(tc) & model.C==mc);
    end
end
%[yvar';model.C']
%[nan 1:nClasses; trueClasses coincCount]

%Shuffle the columns of coincCount to get the one with the best sum(diag(cfnMat)) / sum(sum(cfnMat));
maps = perms(1:nClasses); %Every combination of [1 2 3 4 5 6 7 8] e.g. [8 5 3 4 6 7 1 2]
shuffAcc = nan(size(maps,1),1);
for k = 1:size(maps,1)
    temp = coincCount(:,maps(k,:));
    shuffAcc(k) = sum(diag(temp)) / sum(sum(temp));
end
[~, mapidx] = max(shuffAcc);
classRemap = maps(mapidx,:);
% classRemap(tc) = mc. I actually need the opposite of this for a fast
% remapping from model class to predicted class.
[~, classRemap] = sort(classRemap);
% e.g.
% predY = classRemap(model.C)';
% cfnMat = class2Cfn(trainY, predY);


%% Use model to classify testX
% - take a look at Estep and CalcLike in lrm.m or gmix.m
% - may need to permute(M.Mu, [1 3 2])
info = listmodels(ModelOptions.method);

if strcmpi(info.method, 'lrm')
    [Y, X, Seq] = trajs2seq(testX, model.zero, model.Options.MinLen);
    if (size(X,2) ~= model.order+1)
      X = regmat(X, model.order);
    end

%     M = Estep(M,X,Y,Seq);
    Mu = permute(model.Mu, [1 3 2]);
    [~, ~, K] = size(Mu);
    [N, ~] = size(Y);
    n = length(Seq)-1;
    mlen = max(diff(Seq));

    Piik = zeros(N,K);
    for k=1:K
        Piik(:,k) = mvnormpdf(Y, X*Mu(:,:,k), model.Sigma(:,:,k));
    end

    M.scale = mean(mean(Piik));
    Piik = Piik ./ M.scale;
    for k=1:K
        M.Pik(:,k) = sprod(Piik(:,k), Seq, mlen);
    end
    M.Pik = M.Pik .* (ones(n,1)*model.Alpha');
    
    
%     [Lhood(NumIter),M] = CalcLike(M,N,PROGNAME);
    [~, K] = size(M.Pik);
    s = sum(M.Pik, 2);
    if (~all(s))
      z = find(s==0);
      Pik(z,:) = realmin*1e100*(ones(length(z),1)*model.Alpha');
      s(z) = sum(Pik(z,:),2);
    end
%     Lhood = sum(log(s)) + N*log(M.scale);
    M.Pik = M.Pik ./ (s*ones(1,K));  % normalize the memberships while were at it
    
    [~, predY] = max(M.Pik,[],2);
    
elseif strcmpi(info.method, 'gmix')
    %TODO
end
predY = classRemap(predY)';